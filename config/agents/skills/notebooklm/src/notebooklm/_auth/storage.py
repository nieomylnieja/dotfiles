"""Cookie storage snapshot/delta persistence helpers for authentication."""

from __future__ import annotations

import contextlib
import errno
import logging
import os
import random
import sys
import threading
import time
import warnings
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import Any, NamedTuple, TypeAlias

import httpx

from . import cookie_policy as _cookie_policy
from . import cookies as _auth_cookies

logger = logging.getLogger("notebooklm.auth")

CookieKey: TypeAlias = _auth_cookies.CookieKey
_cookie_is_http_only = _auth_cookies._cookie_is_http_only
_cookie_key_variants = _auth_cookies._cookie_key_variants
_cookie_to_storage_state = _auth_cookies._cookie_to_storage_state
_find_cookie_for_storage = _auth_cookies._find_cookie_for_storage
_is_allowed_cookie_domain = _cookie_policy._is_allowed_cookie_domain


class CookieSnapshotKey(NamedTuple):
    """Path-aware cookie identity used by the snapshot/delta save machinery.

    RFC 6265 treats ``path`` as part of cookie identity: two cookies with the
    same ``(name, domain)`` but different paths are distinct entries. The
    snapshot/delta path widens the legacy ``(name, domain)`` key (still used
    elsewhere for back-compat — see ``CookieKey``) to ``(name, domain, path)``
    so that path-scoped cookies (e.g. ``OSID`` on a per-product path) survive
    a load → save round trip and so that a sibling-process write to a
    different-path variant of the same name is not silently overwritten.
    """

    name: str
    domain: str
    path: str


class CookieSnapshotValue(NamedTuple):
    """Snapshot value tuple: ``(value, expires, secure, http_only)``.

    Widened from a bare ``str`` so that a ``Set-Cookie`` which keeps the same
    value but renews ``expires`` (or flips ``secure`` / ``httpOnly``) still
    registers as a delta. The legacy save path compared ``expires`` directly
    and would write the new expiry through; the snapshot path previously
    keyed on value alone and silently dropped attribute-only refreshes.
    """

    value: str
    expires: int | None
    secure: bool
    http_only: bool


CookieSnapshot: TypeAlias = dict[CookieSnapshotKey, CookieSnapshotValue]
# ``None`` is a private observation marker for a pre-existing target row whose
# value was empty, missing, or non-string.  It lets recovery replace an unusable
# row while still treating a newly-written non-empty sibling as a CAS conflict.
RecoveryCookieObservation: TypeAlias = dict[CookieSnapshotKey, frozenset[str | None]]


@dataclass(frozen=True)
class CookieSaveResult:
    """Detailed result for callers that need to maintain a save baseline."""

    ok: bool
    cas_rejected_keys: frozenset[CookieSnapshotKey] = frozenset()


# Errnos that a non-blocking lock acquire raises to mean "held elsewhere"
# (contended), NOT "infrastructure broken". EWOULDBLOCK/EAGAIN are the POSIX
# ``flock(LOCK_NB)`` contention signals. ``EACCES`` is here specifically because
# it is the errno Windows ``msvcrt.locking(LK_NBLCK)`` raises under contention —
# POSIX ``flock`` never returns EACCES for contention, and a POSIX *permission*
# failure surfaces earlier at the ``os.open`` step (yielded as "unavailable").
# So do NOT drop EACCES to "fix" it: on Windows that would misclassify real
# contention as an infrastructure failure (fail-open) instead of a skip.
_LOCK_CONTENTION_ERRNOS = {errno.EWOULDBLOCK, errno.EAGAIN, errno.EACCES}


# --- Bounded-acquire tuning (single source of truth) ------------------------
#
# Shared by BOTH bounded acquire paths so they honour the same deadline and the
# same jittered exponential backoff:
#   * the blocking Windows ``msvcrt`` retry loop in ``_acquire_os_lock`` below
#     ([storage-F4]: Windows has no blocking-without-internal-timeout primitive,
#     so the blocking path drives ``LK_NBLCK`` probes to this deadline instead
#     of letting ``LK_LOCK`` fail open after its internal ~10x1s), and
#   * ``storage_writer._acquire_storage_lock`` (the non-blocking-probe bounded
#     helper that the fail-closed RMW / re-mint writers use), which imports these.
# 90 s is a generous worst-case wait that still bounds a crashed/wedged holder.
# See ADR-0029.
_LOCK_ACQUIRE_DEADLINE_SECONDS = 90.0
_LOCK_ACQUIRE_INITIAL_DELAY_SECONDS = 0.01
_LOCK_ACQUIRE_MAX_DELAY_SECONDS = 0.5


def _sleep_backoff(delay: float, deadline: float) -> float | None:
    """Sleep one jittered exponential-backoff step of a bounded-acquire loop.

    The single home for the deadline-check + jitter + sleep + delay-bump
    arithmetic shared by BOTH bounded-acquire loops — the Windows ``msvcrt``
    retry in :func:`_acquire_os_lock` below and
    ``storage_writer._acquire_storage_lock`` — so future tuning edits one site
    (b-PR4 review NIT). Behaviour is identical to the two former inline copies:
    equal jitter (``delay + U[0, delay]``) clamped to the remaining budget,
    then ``delay`` doubled and capped at :data:`_LOCK_ACQUIRE_MAX_DELAY_SECONDS`.

    Returns the next ``delay`` to use, or ``None`` when the ``deadline`` has
    already elapsed — the caller must then stop retrying and fall through to
    ``"unavailable"`` (each caller keeps its own site-specific give-up log line).
    """
    now = time.monotonic()
    if now >= deadline:
        return None
    sleep_for = min(delay + random.uniform(0.0, delay), max(0.0, deadline - now))
    time.sleep(sleep_for)
    return min(delay * 2, _LOCK_ACQUIRE_MAX_DELAY_SECONDS)


# In-process lock registry, keyed per canonical lock-path (never global — distinct
# profiles and the rotate sentinel must not couple). Acquired BEFORE the OS lock
# (ordering: in-process lock -> OS lock) so threads within one process serialize
# on a storage sentinel before touching the OS flock, which both bounds Windows
# ``msvcrt`` contention and lets the non-blocking rotate path observe an
# in-process holder as "contended" without an OS round-trip. See ADR-0029.
_INPROCESS_LOCKS: dict[str, threading.Lock] = {}
_INPROCESS_LOCKS_GUARD = threading.Lock()


def _inprocess_lock_for(lock_path: Path) -> threading.Lock:
    """Return the process-wide :class:`threading.Lock` for ``lock_path``."""
    key = os.fspath(lock_path)
    with _INPROCESS_LOCKS_GUARD:
        lock = _INPROCESS_LOCKS.get(key)
        if lock is None:
            lock = threading.Lock()
            _INPROCESS_LOCKS[key] = lock
        return lock


def _acquire_os_lock(fd: int, *, blocking: bool, log_prefix: str) -> str:
    """Acquire the OS-level exclusive lock on ``fd``; return the tristate.

    Returns one of ``"held"`` / ``"contended"`` / ``"unavailable"``. The caller
    (:func:`_file_lock`) has already taken the per-path in-process
    :class:`threading.Lock` (ordering: in-process lock -> OS lock), so any
    contention observed here is from **another process**, never another thread in
    this process.

    * **POSIX** — ``flock(LOCK_EX)`` when blocking (a kernel-level wait: unbounded
      but non-spinning, unchanged), ``LOCK_EX | LOCK_NB`` when non-blocking.
    * **Windows** — ``msvcrt`` has no blocking-without-internal-timeout primitive:
      the blocking ``LK_LOCK`` mode gives up after ~10x1s and would fail open
      long before the 90 s deadline ([storage-F4]). So the Windows **blocking**
      path drives a bounded deadline retry over the **non-blocking** ``LK_NBLCK``
      probe using the same jittered exponential backoff as
      :func:`storage_writer._acquire_storage_lock`, retrying **only** on the
      contention errno and falling through to ``"unavailable"`` when the deadline
      elapses (never ``while True`` without a deadline break). A non-contention
      errno (``EBADF`` etc.) falls through immediately with **no** retry spin.
      Windows non-blocking is a single ``LK_NBLCK`` probe.
    """
    if sys.platform != "win32":
        import fcntl

        op = fcntl.LOCK_EX if blocking else fcntl.LOCK_EX | fcntl.LOCK_NB
        try:
            fcntl.flock(fd, op)
            return "held"
        except OSError as exc:
            if not blocking and exc.errno in _LOCK_CONTENTION_ERRNOS:
                logger.debug("%s: lock contended (%s)", log_prefix, type(exc).__name__)
                return "contended"
            logger.debug("%s: lock op unavailable (%s)", log_prefix, type(exc).__name__)
            return "unavailable"

    import msvcrt

    deadline = time.monotonic() + _LOCK_ACQUIRE_DEADLINE_SECONDS
    delay = _LOCK_ACQUIRE_INITIAL_DELAY_SECONDS
    while True:
        try:
            msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
            return "held"
        except OSError as exc:
            if exc.errno not in _LOCK_CONTENTION_ERRNOS:
                # EBADF and other non-contention errnos: retrying cannot help.
                # Fall through immediately — no spin.
                logger.debug("%s: lock op unavailable (%s)", log_prefix, type(exc).__name__)
                return "unavailable"
            if not blocking:
                # Non-blocking caller: another process holds the byte-range lock
                # (in-process contention was already resolved by the threading
                # lock in _file_lock). Report the skip signal without retrying.
                logger.debug("%s: lock contended (%s)", log_prefix, type(exc).__name__)
                return "contended"
            # Blocking caller under contention: retry the non-blocking probe with
            # jittered exponential backoff until the bounded deadline, then fall
            # through to "unavailable" so the caller applies its per-intent fail
            # policy (CAS fail-open with a one-shot warning).
            next_delay = _sleep_backoff(delay, deadline)
            if next_delay is None:
                logger.debug(
                    "%s: bounded msvcrt lock acquire exceeded %.0fs deadline; giving up",
                    log_prefix,
                    _LOCK_ACQUIRE_DEADLINE_SECONDS,
                )
                return "unavailable"
            delay = next_delay


@contextlib.contextmanager
def _file_lock(lock_path: Path, *, blocking: bool, log_prefix: str) -> Iterator[str]:
    """Cross-process exclusive lock on ``lock_path``.

    Yields one of:
      - ``"held"``  — the lock is held; release it on exit.
      - ``"contended"`` — non-blocking acquire saw the lock held elsewhere
        (by another in-process thread OR another process). Only ever yielded
        when ``blocking=False``.
      - ``"unavailable"`` — lock infrastructure failed (cannot mkdir, cannot
        open the sentinel, NFS without flock support). Caller should
        **fail open** (proceed without coordination) rather than retry forever.

    Wrappers translate this tristate into bool. Distinguishing contention from
    infrastructure failure matters: a non-blocking caller should **skip** on
    contention (someone else is rotating) but **proceed** on infrastructure
    failure (otherwise a read-only auth dir would permanently suppress
    rotation).

    Locking order is **in-process lock -> OS lock**: the per-path
    :class:`threading.Lock` is taken first (blockingly for ``blocking=True``,
    non-blockingly for ``blocking=False`` where a failed acquire maps straight to
    ``"contended"``), then the OS-level flock/``msvcrt`` lock. The in-process
    lock is released last.
    """
    inprocess_lock = _inprocess_lock_for(lock_path)
    if not inprocess_lock.acquire(blocking=blocking):
        # Only reachable with ``blocking=False``: another thread in this process
        # holds the sentinel. Report contention without touching the OS lock.
        logger.debug("%s: in-process lock contended", log_prefix)
        yield "contended"
        return
    try:
        try:
            lock_path.parent.mkdir(parents=True, exist_ok=True)
            fd = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
        except OSError as exc:
            # Read-only directory, permission denied, ENOSPC, etc. Yield
            # "unavailable" so the wrapper can fail open.
            logger.debug(
                "%s: lock file unavailable %s (%s)",
                log_prefix,
                lock_path,
                type(exc).__name__,
            )
            yield "unavailable"
            return
        locked = False
        try:
            # OS-lock acquisition (in-process lock already held above). On Windows
            # the blocking path is a bounded ``LK_NBLCK`` retry to the shared 90 s
            # deadline rather than ``LK_LOCK``'s internal ~10x1s ([storage-F4]).
            state = _acquire_os_lock(fd, blocking=blocking, log_prefix=log_prefix)
            locked = state == "held"
            yield state
        finally:
            if locked:
                try:
                    if sys.platform == "win32":
                        import msvcrt

                        msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
                    else:
                        import fcntl

                        fcntl.flock(fd, fcntl.LOCK_UN)
                except OSError as exc:
                    logger.debug(
                        "%s: failed to release file lock (%s)",
                        log_prefix,
                        type(exc).__name__,
                    )
            os.close(fd)
    finally:
        inprocess_lock.release()


# Dedupe contract: best-effort under threads, exactly-once on a single
# event loop. ``_file_lock_exclusive`` below reads ``_FLOCK_UNAVAILABLE_WARNED``
# and sets it to ``True`` in one synchronous block with no intervening
# ``await``, so concurrent coroutines on one loop cannot interleave between
# the check and the set — the warning fires exactly once per process. Under
# genuine OS threads (out of scope per the documented concurrency contract),
# duplicate warnings are possible. We accept that rather than serialize a
# logging side-effect behind a lock for an unsupported configuration.
#
# Note: ``functools.lru_cache`` and ``logging.LoggerAdapter`` do NOT solve
# this — ``lru_cache`` memoizes return values, not the ``logger.warning``
# side-effect; ``LoggerAdapter`` only rewrites records, it does not filter
# duplicates.
_FLOCK_UNAVAILABLE_WARNED = False


@contextlib.contextmanager
def _file_lock_exclusive(lock_path: Path) -> Iterator[None]:
    """Blocking cross-process exclusive lock on ``lock_path``.

    Multiple Python processes that all save to the same ``storage_state.json``
    (e.g. a long-running ``NotebookLMClient(keepalive=...)`` worker plus a
    cron-driven ``notebooklm auth refresh``) would otherwise race on the read-
    merge-write cycle and lose updates. The lock is held on a sentinel file
    sibling to the storage file (``.storage_state.json.lock``, derived by
    :func:`notebooklm._auth.paths._storage_state_lock_path`), since locking the
    storage file itself would interfere with the atomic temp-rename below.

    ``_auth/account.py`` holds this *same* sentinel via ``filelock.FileLock``
    when it writes account metadata into ``storage_state.json``. The two
    mechanisms interoperate because ``filelock.FileLock`` also uses
    ``fcntl.flock`` on POSIX, so an exclusive hold from either side blocks the
    other — that cross-mechanism compatibility is what lets cookie saves and
    account-metadata writes serialize on one file.

    The lock is per-process: threads within one process aren't serialized —
    that's the intra-process ``threading.Lock`` held by the client. If the
    lock can't be acquired (e.g. NFS where flock semantics vary, read-only
    parent dir, fd exhaustion), the save proceeds anyway; correctness in
    that mode is best-effort and relies on the snapshot/delta CAS guards in
    :func:`_merge_cookies_with_snapshot` alone. The first time this
    fallback fires per process emits a WARNING so operators learn their
    deployment is running without cross-process coordination.
    """
    global _FLOCK_UNAVAILABLE_WARNED
    with _file_lock(lock_path, blocking=True, log_prefix="save_cookies_to_storage") as state:
        if state == "unavailable" and not _FLOCK_UNAVAILABLE_WARNED:
            _FLOCK_UNAVAILABLE_WARNED = True
            logger.warning(
                "Cross-process file lock unavailable at %s; cookie saves will "
                "proceed without cross-process coordination and rely solely on "
                "snapshot/delta CAS guards. Common causes: NFS without flock "
                "support, read-only parent directory, fd exhaustion. (Logged "
                "once per process.)",
                lock_path,
            )
        yield


def snapshot_cookie_jar(cookie_jar: httpx.Cookies) -> CookieSnapshot:
    """Capture an open-time snapshot of an httpx cookie jar.

    Snapshots are the input to the dirty-flag/delta merge in
    :func:`save_cookies_to_storage`: at save time, only cookies whose
    in-memory value differs from the snapshot — plus cookies absent from
    the jar but present in the snapshot (deletions) — are propagated to
    disk. Cookies the in-process code never touched are left to whatever
    a sibling process may have written (closes the §3.4.1
    stale-overwrite-fresh hazard).

    The key shape is path-aware ``(name, domain, path)`` (also closes
    §3.4.2). Cookies with no name or no domain are skipped — the storage
    format requires both.

    Args:
        cookie_jar: The httpx.Cookies object to snapshot.

    Returns:
        Mapping of ``CookieSnapshotKey -> CookieSnapshotValue`` capturing
        each cookie's value and the attributes the storage_state schema
        persists (``expires``, ``secure``, ``httpOnly``).
    """
    return {
        CookieSnapshotKey(cookie.name, cookie.domain, cookie.path or "/"): CookieSnapshotValue(
            value=cookie.value,
            expires=cookie.expires,
            secure=bool(cookie.secure),
            http_only=_cookie_is_http_only(cookie),
        )
        for cookie in cookie_jar.jar
        if cookie.name and cookie.domain and cookie.value is not None
    }


def _cookie_snapshot_key_variants(key: CookieSnapshotKey) -> set[CookieSnapshotKey]:
    """Return equivalent host/domain snapshot keys for leading-dot domains.

    Mirrors :func:`_cookie_key_variants` but preserves the path component so
    storage entries on the same path match snapshot entries regardless of
    whether ``http.cookiejar`` normalized the domain to a leading dot.
    """
    variants = {key}
    if key.domain.startswith("."):
        variants.add(CookieSnapshotKey(key.name, key.domain[1:], key.path))
    else:
        variants.add(CookieSnapshotKey(key.name, f".{key.domain}", key.path))
    return variants


def _stored_cookie_snapshot_key(stored_cookie: Any) -> CookieSnapshotKey | None:
    """Build a path-aware snapshot key from a Playwright storage_state cookie."""
    if not isinstance(stored_cookie, dict):
        return None
    name = stored_cookie.get("name")
    domain = stored_cookie.get("domain", "")
    if not isinstance(name, str) or not name:
        return None
    if not isinstance(domain, str) or not domain:
        return None
    raw_path = stored_cookie.get("path")
    if raw_path is not None and not isinstance(raw_path, str):
        return None
    path = raw_path or "/"
    return CookieSnapshotKey(name, domain, path)


def advance_cookie_snapshot_after_save(
    original_snapshot: CookieSnapshot | None,
    post_save_snapshot: CookieSnapshot,
    cas_rejected_keys: frozenset[CookieSnapshotKey],
) -> CookieSnapshot | None:
    """Advance save baseline for successful keys while preserving rejected ones.

    A save can partially succeed: one cookie delta may write through while a
    sibling-process CAS conflict rejects another. Advancing the whole baseline
    would lose the rejected delta; keeping the whole old baseline would replay
    already-written deltas and wedge future saves. This helper advances every
    key to ``post_save_snapshot`` except the CAS-rejected keys, which retain
    their old baseline value or absence. Rejected keys are matched through
    leading-dot variants because the merge path can reject a normalized variant
    of the key captured in ``original_snapshot``.
    """
    if original_snapshot is None:
        return None

    advanced = dict(post_save_snapshot)
    for key in cas_rejected_keys:
        original_key = next(
            (
                variant
                for variant in _cookie_snapshot_key_variants(key)
                if variant in original_snapshot
            ),
            None,
        )
        for variant in _cookie_snapshot_key_variants(key):
            advanced.pop(variant, None)
        if original_key is not None:
            advanced[original_key] = original_snapshot[original_key]
    return advanced


def _cookie_save_return(
    result: CookieSaveResult, *, return_result: bool
) -> bool | CookieSaveResult:
    """Return either the detailed save result or its public bool projection."""
    return result if return_result else result.ok


def save_cookies_to_storage(
    cookie_jar: httpx.Cookies,
    path: Path | None = None,
    *,
    original_snapshot: CookieSnapshot | None = None,
    recovery_observation: RecoveryCookieObservation | None = None,
    return_result: bool = False,
) -> bool | CookieSaveResult:
    """Save an updated httpx.Cookies jar back to Playwright storage_state.json.

    This ensures that when Google issues short-lived token refreshes (e.g.
    during 302 redirects to accounts.google.com), those updated cookies are
    serialized back to disk so the session remains valid across CLI invocations.

    If auth was loaded from an environment variable (no file), this is a no-op.

    Cross-process safety: the read-merge-write cycle is wrapped in an OS-level
    file lock (``.storage_state.json.lock``) so concurrent writers from
    different Python processes (e.g. an in-process ``NotebookLMClient`` keepalive
    plus a cron-driven ``notebooklm auth refresh``) serialize cleanly rather
    than tearing or losing updates.

    Two merge modes:

    - **Legacy (``original_snapshot=None``)**: every in-memory cookie whose
      value differs from disk wins. Vulnerable to the stale-overwrite-fresh
      race documented in ``docs/auth-cookie-lifecycle.md`` §3.4.1 and emits a
      ``RuntimeWarning`` safety advisory about that race (this is a permanent
      back-compat shim, not a scheduled deprecation, so the advisory is a
      ``RuntimeWarning`` and is not silenced by ``NOTEBOOKLM_QUIET_DEPRECATIONS``).
      Kept only as a public-API back-compat shim for callers outside this repo;
      every first-party caller passes ``original_snapshot``.
    - **Snapshot/delta (``original_snapshot`` provided)**: only cookies
      whose in-memory persisted tuple differs from the snapshot are written, and
      cookies present in the snapshot but no longer in the jar are
      deleted from disk. Cookies the in-process code never touched are
      left untouched on disk so a sibling-process write survives.
      Path-aware ``(name, domain, path)`` keys are used here (also closes
      §3.4.2).

    Args:
        cookie_jar: The httpx.Cookies object containing the latest cookies.
        path: Path to storage_state.json. If None, cookie sync is skipped.
        original_snapshot: Open-time snapshot from
            :func:`snapshot_cookie_jar`. When provided, only deltas and
            deletions relative to the snapshot are persisted.
        return_result: Internal escape hatch for callers that need CAS-rejected
            keys to maintain a per-cookie baseline. Public callers should use
            the default bool return.

    Returns:
        ``True`` if the disk state now reflects the caller's intent (write
        succeeded, was a successful no-op, or the call was a deliberate skip
        because auth was loaded from an env var). ``False`` if an I/O error
        prevented the save or a CAS guard preserved a sibling-process write.
        With ``return_result=True``, callers can inspect CAS-rejected keys and
        advance their baseline for the keys that did write through.
    """
    if original_snapshot is None and path is not None:
        # NOT a deprecation: the original_snapshot=None form is a *permanent*
        # public-API back-compat shim (docs/auth-cookie-lifecycle.md §3.4.1),
        # not a scheduled removal — every in-tree caller already passes a
        # snapshot. The warning is a runtime safety advisory about the
        # stale-overwrite-fresh race that path is vulnerable to, so it is a
        # RuntimeWarning, not a DeprecationWarning. It is therefore outside
        # ADR-0018's scope: no NOTEBOOKLM_QUIET_DEPRECATIONS gate, no removal
        # version, and emitted directly here rather than via warn_deprecated.
        # Emitted on THIS delegate (not the relocated merge body) so
        # ``stacklevel=2`` still points at the caller.
        warnings.warn(
            "save_cookies_to_storage called without original_snapshot; the "
            "legacy full-merge path is vulnerable to the stale-overwrite-fresh "
            "race (docs/auth-cookie-lifecycle.md §3.4.1). Pass an original_snapshot "
            "captured via snapshot_cookie_jar() at jar-open time.",
            RuntimeWarning,
            stacklevel=2,
        )

    # Canonical patch seam: the CAS delta merge body lives in
    # :func:`notebooklm._auth.storage_writer.merge_cookie_delta`. This module-level
    # ``save_cookies_to_storage`` symbol stays here as the monkeypatchable
    # delegate (~18 test files patch it; ``_runtime/lifecycle.py`` late-binds it).
    from . import storage_writer  # local import: avoid the storage<->writer cycle

    return storage_writer.merge_cookie_delta(
        cookie_jar,
        path,
        original_snapshot=original_snapshot,
        recovery_observation=recovery_observation,
        return_result=return_result,
    )


def _preserved_same_site(stored_cookie: dict[str, Any], fresh_state: dict[str, Any]) -> str:
    """Keep a stored ``sameSite`` instead of the merge default that erases it.

    ``http.cookiejar.Cookie`` carries no SameSite attribute, so
    :func:`_cookie_to_storage_state` can only emit the ``"None"`` default. Writing
    that back over a row captured with ``"Lax"``/``"Strict"`` would downgrade it on
    every rotation, quietly undoing the attribute preservation the capture and
    rookiepy converters perform.
    """
    stored = stored_cookie.get("sameSite")
    if stored in {"Strict", "Lax", "None"}:
        return str(stored)
    return str(fresh_state["sameSite"])


def _merge_cookies_legacy(cookie_jar: httpx.Cookies, storage_data: dict[str, Any]) -> int:
    """Legacy merge: trust in-memory whenever it differs from disk.

    Vulnerable to the stale-overwrite-fresh race (§3.4.1). Kept only for
    callers that have not yet opted into snapshot semantics. New callers
    must pass ``original_snapshot`` to :func:`save_cookies_to_storage`.

    Returns:
        Number of cookie entries added or modified in ``storage_data``.
    """
    cookies_by_key: dict[CookieKey, Any] = {
        (cookie.name, cookie.domain, cookie.path or "/"): cookie
        for cookie in cookie_jar.jar
        if cookie.name and cookie.domain and _is_allowed_cookie_domain(cookie.domain)
    }

    updated_count = 0
    stored_keys: set[CookieKey] = set()
    for stored_cookie in storage_data["cookies"]:
        if not isinstance(stored_cookie, dict):
            continue
        name = stored_cookie.get("name")
        domain = stored_cookie.get("domain", "")
        if not isinstance(name, str) or not name or not isinstance(domain, str) or not domain:
            continue

        stored_key = _stored_cookie_snapshot_key(stored_cookie)
        if stored_key is None:
            continue
        key: CookieKey = stored_key
        stored_keys.update(_cookie_key_variants(key))
        refreshed_cookie = _find_cookie_for_storage(cookies_by_key, key, stored_cookie.get("value"))
        if refreshed_cookie is None:
            continue

        fresh_state = _cookie_to_storage_state(refreshed_cookie)
        new_expires = fresh_state["expires"]
        changed = (
            stored_cookie.get("value") != refreshed_cookie.value
            or stored_cookie.get("expires") != new_expires
        )
        if changed:
            stored_cookie["value"] = refreshed_cookie.value
            stored_cookie["expires"] = new_expires
            # Normalize present-but-empty ``"path": ""`` to ``"/"`` so the row
            # we write matches the path normalization used to build the
            # identity key one block up (and used by every loader). Without
            # the trailing ``or "/"`` an on-disk row with ``"path": ""`` would
            # survive across save cycles while every other code path treats
            # it as ``"/"``.
            stored_cookie["path"] = refreshed_cookie.path or stored_cookie.get("path") or "/"
            stored_cookie["secure"] = refreshed_cookie.secure
            stored_cookie["httpOnly"] = _cookie_is_http_only(refreshed_cookie)
            stored_cookie["sameSite"] = _preserved_same_site(stored_cookie, fresh_state)
            updated_count += 1

    for key, cookie in cookies_by_key.items():
        if key in stored_keys:
            continue
        storage_data["cookies"].append(_cookie_to_storage_state(cookie))
        updated_count += 1

    return updated_count


_RECOVERY_TARGET_COOKIE_NAMES = frozenset({"__Secure-1PSIDTS", "__Secure-3PSIDTS"})


def _merge_recovery_target_rows(
    storage_cookies: list[Any],
    deltas: dict[CookieSnapshotKey, Any],
    observation: RecoveryCookieObservation | None,
) -> tuple[list[Any], int, set[CookieSnapshotKey], set[CookieSnapshotKey]]:
    """Collapse observed recovery targets while preserving sibling conflicts."""
    if observation is None:
        return storage_cookies, 0, set(), set()

    replacements: dict[int, dict[str, Any]] = {}
    removals: set[int] = set()
    appends: list[dict[str, Any]] = []
    handled: set[CookieSnapshotKey] = set()
    cas_rejected: set[CookieSnapshotKey] = set()
    updated_count = 0

    for delta_key, cookie in deltas.items():
        if delta_key.name not in _RECOVERY_TARGET_COOKIE_NAMES:
            continue

        variants = _cookie_snapshot_key_variants(delta_key)
        observed_values: set[str | None] = set()
        for variant in variants:
            observed_values.update(observation.get(variant, frozenset()))
        if not observed_values:
            # No target row was observed before the POST. Let the ordinary
            # snapshot/CAS path decide whether a same-key sibling appeared.
            continue

        row_indices: list[int] = []
        for index, stored_cookie in enumerate(storage_cookies):
            stored_key = _stored_cookie_snapshot_key(stored_cookie)
            if stored_key is not None and variants & _cookie_snapshot_key_variants(stored_key):
                row_indices.append(index)

        fresh_state = _cookie_to_storage_state(cookie)
        replaceable: list[int] = []
        conflicts: list[int] = []
        for index in row_indices:
            stored_cookie = storage_cookies[index]
            stored_value = stored_cookie.get("value") if isinstance(stored_cookie, dict) else None
            stored_value_is_unusable = not isinstance(stored_value, str) or not stored_value
            observed_unusable = None in observed_values
            if (
                stored_value == cookie.value
                or stored_value in observed_values
                or (stored_value_is_unusable and observed_unusable)
            ):
                replaceable.append(index)
            else:
                conflicts.append(index)

        if conflicts:
            # This is the recovery-specific CAS rejection. The sibling rows
            # remain byte-for-byte intact; no stale recovery value may clobber
            # a value that did not exist when the POST started.
            #
            # Deliberately whole-key, even in the mixed case where another row
            # for this identity *was* replaced below: the key is reported as
            # rejected, so ``advance_cookie_snapshot_after_save`` leaves the
            # baseline where it is. A conflicting row is still on disk and the
            # loaders pick a winner among duplicates, so we cannot claim the
            # identity now reads as the value we wrote. Advancing on a partial
            # write would retire a delta that never fully landed.
            cas_rejected.add(delta_key)

        if replaceable:
            winner = replaceable[0]
            # Same ``sameSite`` preservation the ordinary merges apply: only the
            # cookie's *value* and expiry are being refreshed by the rotation,
            # and ``fresh_state`` can only carry the ``"None"`` default, so
            # taking it wholesale would downgrade a captured ``Lax``/``Strict``
            # on the one path recovery owns.
            stored_winner = storage_cookies[winner]
            replacements[winner] = {
                **fresh_state,
                "sameSite": _preserved_same_site(
                    stored_winner if isinstance(stored_winner, dict) else {}, fresh_state
                ),
            }
            removals.update(replaceable[1:])
            updated_count += 1 + len(replaceable[1:])
            handled.add(delta_key)
        elif not row_indices:
            appends.append(fresh_state)
            updated_count += 1
            handled.add(delta_key)
        elif conflicts:
            # Preserve an unobserved sibling exactly. The ordinary new-cookie
            # CAS path would likewise decline to append over an existing row.
            handled.add(delta_key)

    merged: list[Any] = []
    for index, stored_cookie in enumerate(storage_cookies):
        if index in removals:
            continue
        merged.append(replacements.get(index, stored_cookie))
    merged.extend(appends)
    return merged, updated_count, cas_rejected, handled


def _merge_cookies_with_snapshot(
    cookie_jar: httpx.Cookies,
    storage_data: dict[str, Any],
    original_snapshot: CookieSnapshot,
    *,
    recovery_observation: RecoveryCookieObservation | None = None,
) -> tuple[int, frozenset[CookieSnapshotKey]]:
    """Snapshot/delta merge: write only what this process actually changed.

    Closes §3.4.1 (stale-overwrite-fresh) and §3.4.2 (path collapse):

    - **Deltas (CAS-guarded for keys in the snapshot)**: cookies in the
      jar whose snapshot tuple (``value, expires, secure, http_only``)
      differs from ``original_snapshot`` are written to disk **only if**
      the on-disk value still matches the snapshot value. If disk has
      rotated since open time, a sibling process has written it; we
      preserve their write rather than clobber it with our local
      rotation. New cookies acquired during the session are written only
      when no same-key storage row exists yet; an existing row means a
      sibling acquired the same cookie first. Comparing the full snapshot
      tuple keeps attribute-only refreshes (same value, new ``expires``)
      flowing to disk, but CAS remains value-only because attribute-only
      sibling drift is routine session metadata and should not wedge later
      value rotations.
    - **Deletions (CAS-guarded)**: a key present in the snapshot but
      absent from the jar is dropped from disk **only if** the on-disk
      value still matches the snapshot value — symmetric with the
      value-update CAS above. An ``Max-Age=0`` that evicted our
      locally-expired copy must not erase the sibling's freshly-issued
      replacement.
    - **Untouched**: cookies in the jar whose tuple matches the snapshot
      are not written, so a sibling-process write to the same key
      survives. Cookies on disk that are not in the snapshot are also
      left alone (they belong to a sibling process or another path).

    Args:
        cookie_jar: Current in-memory cookie jar.
        storage_data: Mutable storage_state.json dict (modified in place).
        original_snapshot: Open-time snapshot of the same jar.

    Returns:
        Tuple of ``(updated_count, cas_rejected_keys)``:

        - ``updated_count``: cookie entries added, modified, or removed
          (drives whether the temp-write step runs).
        - ``cas_rejected_keys``: keys whose CAS check rejected a delta or
          deletion. Caller uses this to advance the baseline only for keys
          that were actually written or already matched.
    """
    current_snapshot = snapshot_cookie_jar(cookie_jar)

    # Path-aware index of jar cookies for delta application. Restricting to
    # _is_allowed_cookie_domain matches the legacy save's allowlist gate so
    # this PR doesn't inadvertently widen the persisted-domain set.
    # Filter ``cookie.value is not None`` to mirror ``snapshot_cookie_jar``: a
    # value-less cookie is treated as a deletion (absent from this index, absent
    # from ``current_snapshot``) rather than a delta that would write ``null``
    # to disk.
    cookies_by_snapshot_key = {
        CookieSnapshotKey(cookie.name, cookie.domain, cookie.path or "/"): cookie
        for cookie in cookie_jar.jar
        if (
            cookie.name
            and cookie.domain
            and cookie.value is not None
            and _is_allowed_cookie_domain(cookie.domain)
        )
    }

    deltas = {
        snapshot_key: cookie
        for snapshot_key, cookie in cookies_by_snapshot_key.items()
        if original_snapshot.get(snapshot_key) != current_snapshot.get(snapshot_key)
    }

    deletion_candidates: set[CookieSnapshotKey] = {
        snapshot_key
        for snapshot_key in original_snapshot
        if snapshot_key not in current_snapshot
        # Only delete cookies the merge would otherwise be allowed to write.
        # Snapshot may include sibling-product domains the allowlist filters
        # out at write time; treating those as deletions would silently drop
        # disk entries we never persisted to begin with.
        and _is_allowed_cookie_domain(snapshot_key.domain)
    }

    updated_count = 0
    cas_rejected_keys: set[CookieSnapshotKey] = set()

    recovery_rows, recovery_updated, recovery_rejected, recovery_handled = (
        _merge_recovery_target_rows(storage_data["cookies"], deltas, recovery_observation)
    )
    updated_count += recovery_updated
    cas_rejected_keys.update(recovery_rejected)
    storage_data["cookies"] = recovery_rows
    merge_deltas = {key: cookie for key, cookie in deltas.items() if key not in recovery_handled}

    # Apply deltas + deletions to the existing storage entries in place.
    new_cookies: list[dict[str, Any]] = []
    matched_delta_keys: set[CookieSnapshotKey] = set(recovery_handled)
    for stored_cookie in storage_data["cookies"]:
        stored_key = _stored_cookie_snapshot_key(stored_cookie)
        if stored_key is None:
            new_cookies.append(stored_cookie)
            continue

        # Find the delta (or deletion) that maps to this stored entry.
        # Match leading-dot domain variants so e.g. snapshot
        # ``.accounts.google.com`` lines up with stored ``accounts.google.com``.
        # A delta wins over a deletion: if the same stored entry matches
        # both (which can happen when httpx normalized one variant), we
        # prefer to update rather than drop, because dropping would lose
        # the rotation we just applied.
        matched_delta_cookie = None
        matched_delta_key: CookieSnapshotKey | None = None
        for variant in _cookie_snapshot_key_variants(stored_key):
            if variant in merge_deltas:
                matched_delta_cookie = merge_deltas[variant]
                matched_delta_key = variant
                break

        if matched_delta_cookie is not None:
            if matched_delta_key is None:  # pragma: no cover - loop invariant
                raise RuntimeError("matched_delta_cookie set without matched_delta_key")
            # CAS-guard for value updates: if our snapshot had this key in any
            # leading-dot variant and disk's current value differs from the
            # snapshot value, a sibling process has rewritten the row between
            # our open and our save. Preserve their write rather than clobber,
            # unless disk has already converged to our current value; in that
            # case the save intent is satisfied and the caller may advance its
            # baseline.
            # Variant-aware lookup mirrors the delta match above: if the snapshot
            # was keyed on ``accounts.google.com`` but the matched delta key is
            # the leading-dot variant, a plain ``.get(matched_delta_key)`` would
            # miss the entry and silently bypass the CAS.
            snapshot_entry = next(
                (
                    original_snapshot[variant]
                    for variant in _cookie_snapshot_key_variants(matched_delta_key)
                    if variant in original_snapshot
                ),
                None,
            )
            stored_value = stored_cookie.get("value")
            if (
                snapshot_entry is not None
                and stored_value != snapshot_entry.value
                and stored_value != matched_delta_cookie.value
            ):
                logger.debug(
                    "Skipped CAS-guarded value update of %s on %s: disk value "
                    "differs from snapshot (sibling write preserved)",
                    matched_delta_key.name,
                    matched_delta_key.domain,
                )
                cas_rejected_keys.add(matched_delta_key)
                matched_delta_keys.add(matched_delta_key)
                new_cookies.append(stored_cookie)
                continue
            if snapshot_entry is None and stored_value != matched_delta_cookie.value:
                logger.debug(
                    "Skipped CAS-guarded value update of new cookie %s on %s: "
                    "disk row already exists (sibling write preserved)",
                    matched_delta_key.name,
                    matched_delta_key.domain,
                )
                cas_rejected_keys.add(matched_delta_key)
                matched_delta_keys.add(matched_delta_key)
                new_cookies.append(stored_cookie)
                continue
            fresh_state = _cookie_to_storage_state(matched_delta_cookie)
            stored_cookie["value"] = matched_delta_cookie.value
            stored_cookie["expires"] = fresh_state["expires"]
            # Mirror :func:`_merge_cookies_legacy`: ``or "/"`` normalizes a
            # present-but-empty ``"path": ""`` so the written row matches the
            # path normalization used by the identity key and every loader.
            stored_cookie["path"] = matched_delta_cookie.path or stored_cookie.get("path") or "/"
            stored_cookie["secure"] = matched_delta_cookie.secure
            stored_cookie["httpOnly"] = _cookie_is_http_only(matched_delta_cookie)
            stored_cookie["sameSite"] = _preserved_same_site(stored_cookie, fresh_state)
            matched_delta_keys.add(matched_delta_key)
            updated_count += 1
            new_cookies.append(stored_cookie)
            continue

        deletion_match = next(
            (
                variant
                for variant in _cookie_snapshot_key_variants(stored_key)
                if variant in deletion_candidates
            ),
            None,
        )
        if deletion_match is not None:
            # CAS-guard: only drop the disk row if its value still matches
            # what we observed at snapshot time. A sibling process may have
            # rewritten this key between our open and our save; clobbering
            # their fresh value with our local eviction would resurrect the
            # exact stale-overwrite-fresh hazard the snapshot path exists
            # to close (just inverted — deletion-of-fresh instead of
            # value-write-of-stale).
            snapshot_value = original_snapshot[deletion_match].value
            if stored_cookie.get("value") == snapshot_value:
                updated_count += 1
                continue  # drop the entry from disk
            cas_rejected_keys.add(deletion_match)

        new_cookies.append(stored_cookie)

    # Append delta cookies that didn't match any existing storage entry
    # (genuinely new cookies acquired during the session).
    for snapshot_key, cookie in merge_deltas.items():
        if snapshot_key in matched_delta_keys:
            continue
        new_cookies.append(_cookie_to_storage_state(cookie))
        updated_count += 1

    storage_data["cookies"] = new_cookies
    return updated_count, frozenset(cas_rejected_keys)
