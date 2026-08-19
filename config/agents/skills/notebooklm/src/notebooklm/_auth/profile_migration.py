"""Legacy account migration components for profile persistence."""

from __future__ import annotations

import atexit
import copy
import json
import logging
import math
import os
import threading
import time
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, ClassVar, Literal, TypeAlias

from filelock import FileLock, Timeout

from .._atomic_io import atomic_write_json
from .cookies import (
    _build_cookie_pair_from_storage_state,
    _load_storage_state,
    _LoadedCookiePair,
)
from .profile_account import (
    ACCOUNT_ROUTE_CLEARED_KEY,
    AccountView,
    ClearAccount,
    DomainSelection,
    KeepAccount,
    ProfileAccount,
    SetAccount,
    parse_profile_account,
)
from .profile_document import ProfileDocument
from .profile_store import LoginWriteRequest, ProfileStore, ReplaceResult

logger = logging.getLogger("notebooklm.auth")

_ACCOUNT_CONTEXT_KEY = "account"

#: How long the ``context.json`` scrub waits for its own file lock. A promotion
#: that is merely *queued* behind this lock is still healthy work in progress,
#: so the exit drain budget has to be able to outlast it — see
#: ``_PROMOTION_EXIT_JOIN_SECONDS``.
_CONTEXT_SCRUB_LOCK_TIMEOUT_SECONDS = 10.0

#: Operator override for the exit drain budget, in float seconds (``0`` = never
#: wait). Owned here rather than in ``_auth.paths`` because this module is its
#: only consumer, matching ``headless_reauth``'s local env-name ownership.
NOTEBOOKLM_PROMOTION_EXIT_TIMEOUT_ENV = "NOTEBOOKLM_PROMOTION_EXIT_TIMEOUT"


@dataclass(frozen=True, slots=True, repr=False)
class InBandAccount:
    record: ProfileAccount


@dataclass(frozen=True, slots=True, repr=False)
class LegacyAccount:
    record: ProfileAccount


@dataclass(frozen=True, slots=True)
class NoAccount:
    pass


ResolvedAccount: TypeAlias = InBandAccount | LegacyAccount | NoAccount


@dataclass(frozen=True, slots=True, repr=False)
class _LoadedProfilePair:
    """One raw profile sample with paired cookies and its account route."""

    cookies: _LoadedCookiePair = field(repr=False)
    account: ProfileAccount | None

    def __post_init__(self) -> None:
        if not isinstance(self.cookies, _LoadedCookiePair) or (
            self.account is not None and not isinstance(self.account, ProfileAccount)
        ):
            raise TypeError("loaded profile pair fields are invalid")


@dataclass(frozen=True, slots=True, repr=False)
class Promoted:
    authoritative: ProfileAccount


@dataclass(frozen=True, slots=True)
class AlreadyInBand:
    pass


@dataclass(frozen=True, slots=True)
class NoLegacyRecord:
    pass


@dataclass(frozen=True, slots=True, repr=False)
class PromotionFailed:
    authoritative_after_failure: ProfileAccount | None = field(default=None, repr=False)


PromotionResult: TypeAlias = Promoted | AlreadyInBand | NoLegacyRecord | PromotionFailed


class LegacyAccountContext:
    """Own legacy ``context.json`` account reads and best-effort scrubs."""

    @staticmethod
    def _path(storage_path: Path) -> Path:
        return storage_path.with_name("context.json")

    def read(self, storage_path: Path) -> dict[str, Any] | None:
        context_path = self._path(storage_path)
        if not context_path.exists():
            return None
        try:
            data = json.loads(context_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            logger.debug("account metadata read failed at %s: %s", context_path, exc)
            return None
        if not isinstance(data, dict):
            return None
        account = data.get(_ACCOUNT_CONTEXT_KEY)
        if not isinstance(account, dict) or not account:
            return None
        return copy.deepcopy(account)

    def scrub(self, storage_path: Path) -> bool:
        """Remove the legacy account key, reporting whether it is gone.

        Returns ``True`` when no legacy account copy remains at rest. A
        ``False`` return means the stale account email is still on disk and is
        reported at ``WARNING``: this used to be swallowed at ``DEBUG``, which
        made the privacy half of the migration fail invisibly (#2223 review).
        ``filelock.Timeout`` subclasses ``OSError``, so the plain ``except
        OSError`` below silently ate the *lock* timeout too — ordinary
        contention between two notebooklm processes was enough.
        """
        context_path = self._path(storage_path)
        if not context_path.exists():
            return True
        lock_path = context_path.with_suffix(context_path.suffix + ".lock")
        try:
            with FileLock(str(lock_path), timeout=_CONTEXT_SCRUB_LOCK_TIMEOUT_SECONDS):
                if not context_path.exists():
                    return True
                try:
                    data = json.loads(context_path.read_text(encoding="utf-8"))
                except (OSError, json.JSONDecodeError) as exc:
                    logger.warning(
                        "Legacy account metadata may still be present in %s: it could not be "
                        "read for cleanup (%s). Re-run `notebooklm login` to rewrite the profile.",
                        context_path,
                        exc,
                    )
                    return False
                if not isinstance(data, dict) or _ACCOUNT_CONTEXT_KEY not in data:
                    return True
                del data[_ACCOUNT_CONTEXT_KEY]
                if data:
                    atomic_write_json(context_path, data)
                else:
                    context_path.unlink()
                return True
        except Timeout:
            logger.warning(
                "Your account email is still stored in %s: the cleanup could not take the file "
                "lock within %.1fs, because another notebooklm process is holding it. The "
                "account itself is migrated; re-run `notebooklm login` to remove the stale copy.",
                context_path,
                _CONTEXT_SCRUB_LOCK_TIMEOUT_SECONDS,
            )
            return False
        except OSError as exc:
            logger.warning(
                "Your account email may still be stored in %s: cleanup failed (%s). "
                "Re-run `notebooklm login` to remove the stale copy.",
                context_path,
                exc,
            )
            return False


def _in_band_route(storage_state: dict[str, Any]) -> tuple[bool, ProfileAccount | None]:
    """Project a present in-band route while preserving legacy absence semantics."""
    namespace = storage_state.get("notebooklm")
    if isinstance(namespace, dict) and namespace.get(ACCOUNT_ROUTE_CLEARED_KEY) is True:
        return True, None
    raw_account = namespace.get("account") if isinstance(namespace, dict) else None
    if not isinstance(raw_account, dict) or not raw_account:
        return False, None
    return True, parse_profile_account(raw_account, view=AccountView.ROUTE)


def _load_profile_pair_pure(
    path: Path | None = None, *, require_routable: bool = True
) -> _LoadedProfilePair:
    """Load cookies and the compatible route without mixing primary generations."""
    storage_state = _load_storage_state(path)
    first_storage_state = storage_state
    route_present, account = _in_band_route(storage_state)
    if not route_present and path is not None:
        legacy_account = LegacyAccountContext().read(path)
        storage_state = _load_storage_state(path)
        route_present, account = _in_band_route(storage_state)
        if not route_present:
            account = (
                None
                if storage_state != first_storage_state
                else parse_profile_account(legacy_account, view=AccountView.ROUTE)
            )
    return _LoadedProfilePair(
        cookies=_build_cookie_pair_from_storage_state(
            storage_state,
            require_routable=require_routable,
        ),
        account=account,
    )


class LegacyAccountMigrator:
    """Own lossless account resolution and retryable embed-before-scrub promotion."""

    def __init__(self, contexts: LegacyAccountContext | None = None) -> None:
        self._contexts = contexts if contexts is not None else LegacyAccountContext()

    @staticmethod
    def _project_in_band(document: Any) -> tuple[InBandAccount, dict[str, Any]] | None:
        if document is None:
            return None
        payload = document.to_json()
        namespace = payload.get("notebooklm")
        if isinstance(namespace, dict) and namespace.get(ACCOUNT_ROUTE_CLEARED_KEY) is True:
            return InBandAccount(ProfileAccount(0, None)), {}
        account = namespace.get(_ACCOUNT_CONTEXT_KEY) if isinstance(namespace, dict) else None
        if not isinstance(account, dict) or not account:
            return None
        record = document.account_for(AccountView.ROUTE)
        if record is None:  # pragma: no cover - a non-empty mapping always has a route view
            raise AssertionError("present account must have a route projection")
        return InBandAccount(record), copy.deepcopy(account)

    @staticmethod
    def _sanitize(raw: dict[str, Any]) -> tuple[ProfileAccount, dict[str, Any]]:
        raw_authuser = raw.get("authuser")
        authuser = raw_authuser if type(raw_authuser) is int and raw_authuser >= 0 else 0
        raw_email = raw.get("email")
        email = raw_email.strip() if isinstance(raw_email, str) and raw_email.strip() else None
        compatibility: dict[str, Any] = {"authuser": authuser}
        if email is not None:
            compatibility["email"] = email
        return ProfileAccount(authuser=authuser, email=email), compatibility

    def _resolve_with_projection(
        self,
        store: ProfileStore,
    ) -> tuple[ResolvedAccount, dict[str, Any]]:
        first = self._project_in_band(store._read_account_document())
        if first is not None:
            return first

        legacy = self._contexts.read(store.path)

        second = self._project_in_band(store._read_account_document())
        if second is not None:
            return second

        if legacy is None:
            return NoAccount(), {}
        record, compatibility = self._sanitize(legacy)
        return LegacyAccount(record), compatibility

    def resolve(self, store: ProfileStore) -> ResolvedAccount:
        result, _compatibility = self._resolve_with_projection(store)
        return result

    def needs_reconciliation(self, storage_path: Path, resolution: ResolvedAccount) -> bool:
        """Return whether a background promotion or stale-copy scrub is needed.

        A legacy resolution always needs promotion. An in-band resolution still
        needs reconciliation when ``context.json`` retains an account copy: the
        process may have stopped after the durable write but before the privacy
        scrub. Checking that second case makes the two-step migration self-heal
        on the next read instead of leaving the email at rest forever (#2228).
        """
        if isinstance(resolution, LegacyAccount):
            return True
        return (
            isinstance(resolution, InBandAccount) and self._contexts.read(storage_path) is not None
        )

    def promote(self, store: ProfileStore) -> PromotionResult:
        if not store.path.exists():
            return NoLegacyRecord()
        legacy = self._contexts.read(store.path)
        if legacy is None:
            return NoLegacyRecord()
        record, _compatibility = self._sanitize(legacy)
        try:
            promoted = store.update_account(record, only_if_absent=True)
        except Exception as exc:  # noqa: BLE001 - migration is best-effort for ordinary failures
            logger.warning("Legacy account promotion failed for %s: %s", store.path, exc)
            return PromotionFailed()

        try:
            self._contexts.scrub(store.path)
        except Exception as exc:  # noqa: BLE001 - a committed binding remains authoritative
            logger.warning("Legacy account context cleanup failed for %s: %s", store.path, exc)
        if promoted:
            logger.info("Promoted legacy account metadata in-band for %s", store.path)
            return Promoted(record)
        return AlreadyInBand()

    def scrub(self, store: ProfileStore) -> bool:
        """Remove the legacy copy; ``False`` means it is still at rest."""
        return self._contexts.scrub(store.path)


ThreadFactory: TypeAlias = Callable[..., threading.Thread]


class LegacyPromotionScheduler:
    """Own per-profile active-work deduplication and detached reconciliation."""

    _process_default_scheduler: ClassVar[LegacyPromotionScheduler]

    def __init__(self, thread_factory: ThreadFactory | None = None) -> None:
        self._registry_lock = threading.Lock()
        # Only an *active* worker suppresses another attempt. A completed,
        # failed, or interrupted attempt must be eligible on the next read so
        # 90-second lock contention and write-then-scrub interruption heal
        # instead of becoming permanent process-lifetime loss (#2228).
        self._active_paths: set[str] = set()
        self._attempted_paths: set[str] = set()
        # Worker -> the profile whose promotion it owns, so an incomplete drain
        # can name the file that may not have been migrated.
        self._workers: dict[threading.Thread, Path] = {}
        # Set, under the registry lock, at the instant a drain concludes there is
        # nothing left to wait for. Past that point a new detached worker would
        # never be joined by anyone, so `schedule` refuses it out loud instead.
        self._drain_closed = False
        self._thread_factory = threading.Thread if thread_factory is None else thread_factory

    @classmethod
    def process_default(cls) -> LegacyPromotionScheduler:
        return cls._process_default_scheduler

    def schedule(self, store: ProfileStore, migrator: LegacyAccountMigrator) -> bool:
        canonical = str(store.ordering_key)
        with self._registry_lock:
            if self._drain_closed:
                # Same lock as the drain's final emptiness check, so the two
                # decisions are atomic: a promotion is either joined by the
                # drain or refused here — never started with nobody to wait.
                logger.warning(
                    "Legacy account promotion for %s was not started because the process is "
                    "already shutting down; its account metadata was not migrated. "
                    "Re-run the command to migrate it.",
                    store.path,
                )
                return False
            if canonical in self._active_paths:
                return False
            self._active_paths.add(canonical)
            self._attempted_paths.add(canonical)
            worker: threading.Thread | None = None
            try:
                worker = self._thread_factory(
                    target=self._run,
                    args=(store, migrator),
                    name="notebooklm-account-promotion",
                    daemon=True,
                )
                self._workers[worker] = store.path
                worker.start()
            except BaseException:
                self._active_paths.discard(canonical)
                if worker is not None:
                    self._workers.pop(worker, None)
                raise
            return True

    def _run(self, store: ProfileStore, migrator: LegacyAccountMigrator) -> None:
        try:
            migrator.promote(store)
        except BaseException as exc:  # noqa: BLE001 - detached workers must not escape
            # WARNING, not DEBUG: `drain` reports a *timed-out* promotion, so
            # leaving the *crashed* one at DEBUG made the louder failure the
            # quieter one — the caller is told everything finished (#2223).
            logger.warning(
                "Legacy account promotion failed for %s: %s. Your account metadata was not "
                "migrated; re-run the command to try again.",
                store.path,
                exc,
            )
        finally:
            with self._registry_lock:
                self._workers.pop(threading.current_thread(), None)
                self._active_paths.discard(str(store.ordering_key))

    def drain(self, timeout: float) -> bool:
        """Join outstanding promotion workers within one overall deadline.

        ``timeout`` is an upper bound shared by every outstanding worker, not a
        per-worker budget: N stalled workers must not multiply the wait. It is
        a *deadline*, not a sleep — the common case (a promotion that already
        finished, or finishes in milliseconds) returns immediately.

        Returns ``True`` when no worker was still running when the budget
        expired, and reports every straggler at ``WARNING`` naming its profile
        — an unobserved timeout here is silent data loss: the process exits,
        the daemon worker is killed mid-write, and nothing else in the system
        ever notices (#2223).

        ``True`` means *the threads finished*, NOT *the migrations succeeded*.
        A promotion that failed or crashed still terminates its worker; those
        outcomes are reported by ``promote`` and ``_run`` on their own.
        """
        deadline = time.monotonic() + timeout
        complete = True
        # Re-snapshot rather than joining one entry list: a worker scheduled
        # after the first snapshot would otherwise be neither joined nor
        # warned about — the exact silence this method exists to remove.
        # ``joined`` keeps each worker to a single join so the loop cannot spin.
        joined: set[threading.Thread] = set()
        while True:
            with self._registry_lock:
                pending = [item for item in self._workers.items() if item[0] not in joined]
                if not pending:
                    # Closing the door under the same lock is what makes this a
                    # decision rather than a guess: no worker can slip in
                    # between "nothing left" and the return.
                    self._drain_closed = True
                    return complete
            for worker, path in pending:
                joined.add(worker)
                remaining = max(deadline - time.monotonic(), 0.0)
                worker.join(remaining)
                if worker.is_alive():
                    complete = False
                    logger.warning(
                        "Legacy account promotion for %s was still running when the shared "
                        "%.1fs exit budget ran out. Your account metadata may be only partly "
                        "migrated, and a stale copy of your account email may remain in the "
                        "sibling context.json. Re-run the command; if this repeats, run "
                        "`notebooklm login` to rewrite the profile, or raise %s.",
                        path,
                        timeout,
                        NOTEBOOKLM_PROMOTION_EXIT_TIMEOUT_ENV,
                    )
            if time.monotonic() >= deadline:
                # The timeout return closes the registry for the same reason the
                # empty return does: this is the only exit drain, so anything
                # scheduled after it would be killed mid-promotion unjoined.
                with self._registry_lock:
                    self._drain_closed = True
                return complete

    def _scheduled_paths_for_tests(self) -> frozenset[str]:
        with self._registry_lock:
            return frozenset(self._attempted_paths)

    def _active_paths_for_tests(self) -> frozenset[str]:
        with self._registry_lock:
            return frozenset(self._active_paths)

    def _workers_for_tests(self) -> frozenset[threading.Thread]:
        with self._registry_lock:
            return frozenset(self._workers)

    def _reset_for_tests(self) -> None:
        with self._registry_lock:
            if self._workers:
                raise RuntimeError("promotion workers must be drained before reset")
            self._active_paths.clear()
            self._attempted_paths.clear()
            # Tests drain the process-default scheduler between cases; without
            # reopening it, every later test's promotion would be refused.
            self._drain_closed = False


LegacyPromotionScheduler._process_default_scheduler = LegacyPromotionScheduler()

# Why 30s and not the 2.0s this used to be (#2223).
#
# The budget is a *ceiling*, not a sleep: a promotion that has already
# finished — the overwhelming common case — joins instantly, so raising the
# ceiling costs a healthy process nothing. What the old 2.0s got wrong is that
# it sat below the latency of an ordinary *uncontended* promotion on a loaded
# machine. One promotion performs two lock acquisitions and two atomic writes
# (``update_account`` then the ``context.json`` scrub); on a contended runner,
# or a laptop with antivirus scanning the profile directory, that routinely
# exceeds two seconds. The write was then abandoned with no signal at all.
#
# It cannot simply be raised to cover the worst case either: a promotion
# blocked behind another process's storage lock may legitimately run for
# ``storage_lock._LOCK_ACQUIRE_DEADLINE_SECONDS`` (90s), and no CLI should
# stall that long on exit. 30s is chosen as an order of magnitude above
# ordinary jitter while staying well inside a human's patience if a genuinely
# stuck promotion is ever waited on; past it, ``drain`` warns rather than
# leaving the loss silent. Operators who need a different trade-off set
# ``NOTEBOOKLM_PROMOTION_EXIT_TIMEOUT`` (``0`` = never wait).
#
# The floor is not a matter of taste: it must exceed
# ``_CONTEXT_SCRUB_LOCK_TIMEOUT_SECONDS``, or a promotion that is simply queued
# behind the context lock is abandoned every single time, by construction.
# ``test_exit_budget_can_outlast_the_scrub_lock_it_waits_on`` pins that.
_PROMOTION_EXIT_JOIN_SECONDS = 30.0


def _promotion_exit_timeout() -> float:
    """Resolve the exit drain budget, honouring the operator override."""
    raw = os.environ.get(NOTEBOOKLM_PROMOTION_EXIT_TIMEOUT_ENV)
    if raw is None or not raw.strip():
        return _PROMOTION_EXIT_JOIN_SECONDS
    try:
        override = float(raw)
    except ValueError:
        logger.warning(
            "Ignoring %s=%r: not a number of seconds; using the %.1fs default.",
            NOTEBOOKLM_PROMOTION_EXIT_TIMEOUT_ENV,
            raw,
            _PROMOTION_EXIT_JOIN_SECONDS,
        )
        return _PROMOTION_EXIT_JOIN_SECONDS
    # ``math.isfinite`` also covers NaN. Rejecting inf matters: ``float()``
    # happily parses "inf" and "1e400", and ``Thread.join(inf)`` then raises
    # OverflowError straight out of the atexit hook — replacing this feature's
    # diagnostic with a shutdown traceback, and skipping every later worker.
    if not math.isfinite(override) or override < 0:
        logger.warning(
            "Ignoring %s=%r: must be a finite, non-negative number of seconds; "
            "using the %.1fs default.",
            NOTEBOOKLM_PROMOTION_EXIT_TIMEOUT_ENV,
            raw,
            _PROMOTION_EXIT_JOIN_SECONDS,
        )
        return _PROMOTION_EXIT_JOIN_SECONDS
    # Finite but huge is the same OverflowError; clamp rather than refuse, so a
    # deliberately generous setting still means "wait as long as possible".
    return min(override, threading.TIMEOUT_MAX)


@atexit.register
def _drain_promotions_at_exit() -> None:
    LegacyPromotionScheduler.process_default().drain(_promotion_exit_timeout())


def replace_profile_from_login(
    path: Path,
    state: Mapping[str, Any],
    *,
    include_domains: set[str] | None,
    include_optional: bool = False,
    account_mode: Literal["keep", "clear", "set"] = "keep",
    account_authuser: int | None = None,
    account_email: str | None = None,
    backup: bool = False,
) -> ReplaceResult:
    """Perform one native path-shaped login/import profile replacement."""
    if account_mode not in {"keep", "clear", "set"}:
        raise ValueError("account_mode must be 'keep', 'clear', or 'set'")
    account: KeepAccount | ClearAccount | SetAccount
    if account_mode == "set":
        if account_authuser is None:
            raise ValueError("account_mode='set' requires account_authuser")
        account = SetAccount(ProfileAccount(account_authuser, account_email))
    else:
        if account_authuser is not None or account_email is not None:
            raise ValueError(f"account_mode='{account_mode}' does not accept account values")
        account = KeepAccount() if account_mode == "keep" else ClearAccount()

    source = ProfileDocument.decode(dict(state))
    selection = DomainSelection(
        include_domains=frozenset(include_domains or ()),
        include_optional=include_optional,
    )
    store = ProfileStore(path)
    request = LoginWriteRequest(
        source=source,
        domain_selection=selection,
        account=account,
        backup=backup,
    )
    writer = LoginProfileWriter(store, LegacyAccountMigrator())
    return writer.write(request)


class LoginProfileWriter:
    """Compose one login replacement with post-commit legacy reconciliation."""

    def __init__(self, store: ProfileStore, migrator: LegacyAccountMigrator) -> None:
        self._store = store
        self._migrator = migrator

    def write(self, request: LoginWriteRequest) -> ReplaceResult:
        source = request.source.to_json()
        namespace = source.get("notebooklm")
        promote = type(request.account) is KeepAccount and not (
            type(namespace) is dict and _ACCOUNT_CONTEXT_KEY in namespace
        )

        result = self._store.replace_from_login(request)
        if not result.ok:
            return result
        if promote:
            self._migrator.promote(self._store)
        else:
            self._migrator.scrub(self._store)
        return result


class AccountMetadataWriter:
    """Compose account writes and clears with post-operation legacy scrub."""

    def __init__(self, store: ProfileStore, migrator: LegacyAccountMigrator) -> None:
        self._store = store
        self._migrator = migrator

    def write(self, record: ProfileAccount) -> None:
        self._store.update_account(record, only_if_absent=False)
        self._migrator.scrub(self._store)

    def clear(self) -> None:
        self._store.clear_account()
        self._migrator.scrub(self._store)


def _drop_legacy_account_key(storage_path: Path) -> None:
    """Compatibility scrub function retained as an exact storage alias."""
    LegacyAccountContext().scrub(storage_path)
