"""Platform-simulated tests for the Windows ``msvcrt`` bounded-retry lock path.

Fix [storage-F4] (b-PR4): before this change the blocking storage-lock path on
Windows used ``msvcrt.locking(LK_LOCK)``, which gives up after msvcrt's internal
~10x1s and made the blocking (CAS) path fall to fail-open after only ~10 s of
contention. The fix drives the **non-blocking** ``LK_NBLCK`` probe in a bounded
deadline/backoff loop (the same 90 s deadline + jittered exponential backoff the
non-blocking-driven ``storage_writer._acquire_storage_lock`` uses), retrying
ONLY on the contention errno and falling through to the tristate ``"unavailable"``
(→ per-intent fail policy + one-shot warning) at the deadline. Never ``while True``
without a deadline break; a non-contention errno falls through immediately with no
spin.

Real >10 s Windows contention is unreproducible in CI, so these tests inject a
fake ``msvcrt`` module and pin ``sys.platform`` to ``"win32"`` — they exercise
the Windows branch of :func:`notebooklm._auth.storage._acquire_os_lock` on Linux
CI. The POSIX path is confirmed unchanged by a native (non-simulated) case.
"""

from __future__ import annotations

import errno
import logging
import os
import sys
import types
from pathlib import Path

import pytest

from notebooklm._auth import storage as storage_mod


def _make_fake_msvcrt(nblck_side_effect):
    """Build a stand-in ``msvcrt`` module.

    ``nblck_side_effect(call_number)`` is invoked for each ``LK_NBLCK`` probe
    (1-based); it returns ``None`` to signal a successful acquire or raises an
    ``OSError`` to simulate contention / infrastructure failure. Any use of the
    blocking ``LK_LOCK`` mode fails loudly — the whole point of the fix is that
    we no longer call it.
    """
    m = types.ModuleType("msvcrt")
    m.LK_LOCK = 1
    m.LK_NBLCK = 2
    m.LK_UNLCK = 0
    calls = {"nblck": 0, "unlck": 0, "lock": 0}

    def locking(fd, mode, nbytes):  # noqa: ARG001 - signature mirrors msvcrt.locking
        if mode == m.LK_UNLCK:
            calls["unlck"] += 1
            return None
        if mode == m.LK_LOCK:
            calls["lock"] += 1
            raise AssertionError(
                "blocking LK_LOCK must not be used after the [storage-F4] fix; "
                "the bounded retry drives LK_NBLCK"
            )
        calls["nblck"] += 1
        return nblck_side_effect(calls["nblck"])

    m.locking = locking
    m._calls = calls  # type: ignore[attr-defined]
    return m


def _simulate_win32(monkeypatch: pytest.MonkeyPatch, fake_msvcrt: types.ModuleType) -> None:
    """Route ``import msvcrt`` to the fake and make the code take the win32 branch."""
    monkeypatch.setitem(sys.modules, "msvcrt", fake_msvcrt)
    monkeypatch.setattr(sys, "platform", "win32")


def _open_sentinel(tmp_path: Path) -> int:
    return os.open(tmp_path / ".storage_state.json.lock", os.O_RDWR | os.O_CREAT, 0o600)


# --- 1. contention N times then success: retries within the deadline --------


def test_win32_blocking_retries_on_contention_then_succeeds(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """EACCES (Windows LK_NBLCK contention) N times then success → 'held'.

    No premature fail-open: the bounded acquire keeps probing within the 90 s
    deadline and returns 'held' on the (N+1)th probe.
    """
    contention_count = 4

    def side(call_n: int):
        if call_n <= contention_count:
            raise OSError(errno.EACCES, "simulated msvcrt contention")
        return None

    fake = _make_fake_msvcrt(side)
    _simulate_win32(monkeypatch, fake)

    fd = _open_sentinel(tmp_path)
    try:
        state = storage_mod._acquire_os_lock(fd, blocking=True, log_prefix="test")
    finally:
        os.close(fd)

    assert state == "held"
    assert fake._calls["nblck"] == contention_count + 1  # retried, no early give-up
    assert fake._calls["lock"] == 0  # never used blocking LK_LOCK


# --- 2. contention past the deadline: bounded fail-open, one-shot warning ----


def test_win32_blocking_bounded_then_fails_open_with_one_warning(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """Persistent EACCES past the deadline → 'unavailable' (not a hang, not a
    ``while True``), and the CAS ``_file_lock_exclusive`` path fails open with
    exactly one WARNING."""

    def side(call_n: int):
        raise OSError(errno.EACCES, "always contended")

    fake = _make_fake_msvcrt(side)
    _simulate_win32(monkeypatch, fake)
    # Tiny deadline so the bounded loop gives up quickly under real time.
    monkeypatch.setattr(storage_mod, "_LOCK_ACQUIRE_DEADLINE_SECONDS", 0.02)
    monkeypatch.setattr(storage_mod, "_FLOCK_UNAVAILABLE_WARNED", False)

    lock_path = tmp_path / ".storage_state.json.lock"
    # Must return (not hang); the block body runs because CAS fails open.
    with (
        caplog.at_level(logging.WARNING, logger="notebooklm.auth"),
        storage_mod._file_lock_exclusive(lock_path),
    ):
        body_ran = True

    assert body_ran is True
    warns = [r for r in caplog.records if "lock unavailable" in r.message.lower()]
    assert len(warns) == 1, f"expected exactly one one-shot warning, got {len(warns)}"
    assert fake._calls["nblck"] >= 2  # retried at least once before the deadline
    assert fake._calls["lock"] == 0


def test_win32_blocking_deadline_is_bounded_directly(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The primitive itself returns 'unavailable' under permanent contention
    rather than spinning forever."""

    def side(call_n: int):
        raise OSError(errno.EACCES, "always contended")

    fake = _make_fake_msvcrt(side)
    _simulate_win32(monkeypatch, fake)
    monkeypatch.setattr(storage_mod, "_LOCK_ACQUIRE_DEADLINE_SECONDS", 0.02)

    fd = _open_sentinel(tmp_path)
    try:
        state = storage_mod._acquire_os_lock(fd, blocking=True, log_prefix="test")
    finally:
        os.close(fd)

    assert state == "unavailable"
    assert fake._calls["lock"] == 0


# --- 3. non-contention errno: immediate fall-through, no retry spin ----------


def test_win32_blocking_non_contention_errno_no_spin(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A non-contention errno (EBADF) falls through to 'unavailable' immediately
    — a single probe, no retry loop."""

    def side(call_n: int):
        raise OSError(errno.EBADF, "bad file descriptor")

    fake = _make_fake_msvcrt(side)
    _simulate_win32(monkeypatch, fake)

    fd = _open_sentinel(tmp_path)
    try:
        state = storage_mod._acquire_os_lock(fd, blocking=True, log_prefix="test")
    finally:
        os.close(fd)

    assert state == "unavailable"
    assert fake._calls["nblck"] == 1  # NO spin
    assert fake._calls["lock"] == 0


def test_win32_nonblocking_single_probe_maps_contention(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The Windows NON-blocking probe (fail-closed writers / keepalive skip path)
    still single-probes and maps EACCES → 'contended' with no retry."""

    def side(call_n: int):
        raise OSError(errno.EACCES, "held elsewhere")

    fake = _make_fake_msvcrt(side)
    _simulate_win32(monkeypatch, fake)

    fd = _open_sentinel(tmp_path)
    try:
        state = storage_mod._acquire_os_lock(fd, blocking=False, log_prefix="test")
    finally:
        os.close(fd)

    assert state == "contended"
    assert fake._calls["nblck"] == 1  # non-blocking never retries


# --- 4. POSIX path unchanged ------------------------------------------------


def test_posix_blocking_path_unchanged(tmp_path: Path) -> None:
    """On POSIX the blocking acquire uses ``flock(LOCK_EX)`` and never touches
    ``msvcrt`` — the fix is Windows-only."""
    if sys.platform == "win32":
        pytest.skip("POSIX-specific: exercises the native flock branch")

    fd = _open_sentinel(tmp_path)
    try:
        state = storage_mod._acquire_os_lock(fd, blocking=True, log_prefix="test")
        assert state == "held"
    finally:
        os.close(fd)


def test_posix_path_does_not_import_msvcrt(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """A poisoned ``msvcrt`` in ``sys.modules`` must never be reached on POSIX."""
    if sys.platform == "win32":
        pytest.skip("POSIX-specific")

    def poison(call_n: int):
        raise AssertionError("POSIX path must not call msvcrt.locking")

    monkeypatch.setitem(sys.modules, "msvcrt", _make_fake_msvcrt(poison))
    # NOTE: sys.platform is left as the real (non-win32) value on purpose.

    fd = _open_sentinel(tmp_path)
    try:
        state = storage_mod._acquire_os_lock(fd, blocking=True, log_prefix="test")
        assert state == "held"
    finally:
        os.close(fd)
