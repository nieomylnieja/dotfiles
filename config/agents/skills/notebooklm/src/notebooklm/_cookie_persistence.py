"""Cookie persistence collaborator for the NotebookLM client runtime."""

from __future__ import annotations

__all__ = ["CookiePersistence", "SaveCookiesToStorage"]

import itertools
import threading
from collections.abc import Awaitable, Callable
from pathlib import Path
from typing import Protocol

import httpx

from ._auth.paths import canonical_storage_key
from ._auth.storage import (
    CookieSaveResult,
    CookieSnapshot,
    advance_cookie_snapshot_after_save,
    snapshot_cookie_jar,
)
from .auth import AuthTokens


class SaveCookiesToStorage(Protocol):
    """Callable shape for the storage writer resolved by ``NotebookLMClient``."""

    def __call__(
        self,
        cookie_jar: httpx.Cookies,
        path: Path | None = None,
        *,
        original_snapshot: CookieSnapshot | None = None,
        return_result: bool = False,
    ) -> bool | CookieSaveResult: ...


ToThread = Callable[[Callable[[], None]], Awaitable[None]]


def _apply_ran_merge(result: bool | CookieSaveResult) -> bool:
    """Did this save actually apply a merge (so the ordering marker may advance)?

    True for a success and for a CAS-partial apply (``ok=False`` WITH
    ``cas_rejected_keys`` — matching ``_advance_baseline_after_save`` and
    ``_cookie_persistence`` §b.3). False for a hard-fail (``ok=False`` WITHOUT
    rejected keys: read/write error, missing file, skipped save) so a newer
    hard-failed dispatch does not suppress an older worker.
    """
    if isinstance(result, CookieSaveResult):
        return result.ok or bool(result.cas_rejected_keys)
    return bool(result)


class CookiePersistence:
    """Owns cookie save snapshots, in-process serialization, and baseline state."""

    def __init__(
        self,
        auth: AuthTokens,
        default_path: Path | None,
        *,
        save_lock: threading.Lock | None = None,
    ) -> None:
        self.auth = auth
        self.default_path = default_path
        self.save_lock = save_lock if save_lock is not None else threading.Lock()
        self.loaded_cookie_snapshot: CookieSnapshot | None = None
        # Save-ordering guard [storage-F3 / refresh-F3]: each save() dispatch is
        # stamped from a monotonic counter (``__next__`` is GIL-atomic — the
        # ordering does not rest on the unenforced one-loop-per-client contract).
        # Under ``save_lock`` a worker drops itself if its sequence is older than
        # the newest sequence that has already applied a merge to the same
        # effective path, so a queued stale save can never overwrite a newer one
        # ("close() must win", per client instance). Keyed per effective path so
        # a newer save to path B never drops an older save to path A.
        self._save_seq = itertools.count()
        self._last_applied_seq: dict[Path, int] = {}

    def capture_open_snapshot(self, jar: httpx.Cookies) -> CookieSnapshot:
        """Capture and publish the baseline used for later delta saves."""
        self.loaded_cookie_snapshot = (
            dict(self.auth.cookie_snapshot)
            if self.auth.cookie_snapshot is not None
            else snapshot_cookie_jar(jar)
        )
        self.auth.cookie_snapshot = self.loaded_cookie_snapshot
        return self.loaded_cookie_snapshot

    async def save(
        self,
        jar: httpx.Cookies,
        path: Path | None = None,
        *,
        save_cookies_to_storage: SaveCookiesToStorage,
        to_thread: ToThread,
    ) -> None:
        """Persist ``jar`` through the shared in-process save lock.

        The jar copy and post-save snapshot are taken before dispatching the
        worker so the background thread never iterates a live
        ``AsyncClient.cookies`` object. The blocking lock is acquired only
        inside the worker closure passed to ``to_thread``.
        """
        effective_path = path if path is not None else self.default_path
        if effective_path is None:
            return
        save_path: Path = effective_path
        # Canonical save-ordering KEY (CodeRabbit #5): collapse two syntactic
        # spellings of the SAME file (relative vs resolved vs ``~``-expanded vs
        # symlinked) to one ``_last_applied_seq`` entry. Keying by the raw
        # ``effective_path`` lets a stale worker hash to a DIFFERENT key, be missed
        # by the drop-check, and write an older jar after a newer one. The WRITE
        # still targets ``save_path`` unchanged; only the ordering key canonicalizes.
        save_key: Path = canonical_storage_key(save_path) or save_path

        # Stamp the dispatch order BEFORE the worker is queued (on the loop
        # thread, so the sequence reflects save() call order, not worker run
        # order). ``next()`` on ``itertools.count`` is atomic under the GIL.
        seq = next(self._save_seq)

        jar_copy = httpx.Cookies(jar)
        post_save_snapshot = snapshot_cookie_jar(jar_copy)

        def _save(
            s: httpx.Cookies = jar_copy,
            p: Path = save_path,
            key: Path = save_key,
            lock: threading.Lock = self.save_lock,
            post: CookieSnapshot = post_save_snapshot,
            persistence: CookiePersistence = self,
            dispatch_seq: int = seq,
        ) -> None:
            """Worker-thread save: hold the in-process lock around the disk write."""
            with lock:
                # Drop a stale worker: a newer save() dispatch has already
                # applied a merge to this path (keyed canonically), so writing our
                # older jar would resurrect the stale-overwrite race. A newer
                # dispatch that only *hard-failed* (see below) does NOT advance the
                # marker, so this older worker still proceeds — its write is
                # strictly newer than disk and dropping it would regress vs today.
                last_applied = persistence._last_applied_seq.get(key, -1)
                if dispatch_seq < last_applied:
                    return
                snap = persistence.loaded_cookie_snapshot
                result = save_cookies_to_storage(
                    s,
                    p,
                    original_snapshot=snap,
                    return_result=True,
                )
                # Advance the per-path marker only after an apply that actually
                # ran the merge (success OR CAS-partial — ``ok=False`` WITH
                # rejected keys). A hard-fail (``ok=False`` WITHOUT rejected
                # keys) does not advance, so the older worker above may proceed.
                if _apply_ran_merge(result) and dispatch_seq > last_applied:
                    persistence._last_applied_seq[key] = dispatch_seq
                persistence._advance_baseline_after_save(snap, post, result)

        await to_thread(_save)

    def _advance_baseline_after_save(
        self,
        original_snapshot: CookieSnapshot | None,
        post_save_snapshot: CookieSnapshot,
        result: bool | CookieSaveResult,
    ) -> None:
        if isinstance(result, CookieSaveResult):
            if result.ok:
                self.loaded_cookie_snapshot = post_save_snapshot
            elif result.cas_rejected_keys:
                self.loaded_cookie_snapshot = advance_cookie_snapshot_after_save(
                    original_snapshot,
                    post_save_snapshot,
                    result.cas_rejected_keys,
                )
            if self.loaded_cookie_snapshot is not None:
                self.auth.cookie_snapshot = self.loaded_cookie_snapshot
        elif result:
            self.loaded_cookie_snapshot = post_save_snapshot
            self.auth.cookie_snapshot = post_save_snapshot
