"""Unit tests for :func:`notebooklm._atomic_io.atomic_update_json`.

The locked read-modify-write helper used to mutate ``context.json`` and
``config.json`` without losing updates across concurrent CLI invocations.
The critical invariant is the concurrent-writer test: two threads racing on
the same path must produce a final state containing BOTH writers' keys
(versus the lost-update outcome where only one writer's payload survives).

Every threaded test here runs through :func:`_run_workers` rather than raw
``threading.Thread`` + ``join``, so that a worker which fails outright can
never be mistaken for a lock that lost an update — see that helper.
"""

from __future__ import annotations

import json
import sys
import threading
import time
from collections.abc import Callable, Sequence
from pathlib import Path

import pytest
from filelock import FileLock, Timeout

from notebooklm._atomic_io import atomic_update_json as atomic_update_json_private
from notebooklm.io import atomic_update_json

# Barrier arrival deadline for the interleaving tests. Without it, a worker that
# dies before reaching the barrier leaves its peer blocked until the global 60s
# pytest-timeout kills the whole run; with it, the peers raise
# ``BrokenBarrierError`` promptly and ``_run_workers`` surfaces that.
_BARRIER_TIMEOUT_SECONDS = 30.0

# Lock-acquire budget for the multi-thread stress test. The contract under test
# is mutual exclusion, NOT the 10s production acquire default, so give
# acquisition real headroom: ``filelock`` polls unfairly (50ms, no queue) and the
# critical section holds the lock across an fsync + os.replace, so on a Windows
# CI runner saturated by ``-n auto`` a thread could lose ~200 consecutive polls
# and blow the default. That killed the worker, which then silently contributed
# no increments and was misreported as a lost update.
_STRESS_LOCK_TIMEOUT_SECONDS = 30.0

# Raised above the global 60s ceiling (pyproject ``timeout = 60``) so that a
# slow-but-correct run using the acquire headroom above is not killed mid-flight.
_STRESS_TEST_TIMEOUT_SECONDS = 120


def _run_workers(workers: Sequence[Callable[[], None]]) -> None:
    """Run ``workers`` on threads, re-raising the first failure in the caller.

    ``threading.Thread`` swallows worker exceptions: ``join()`` returns normally
    and the failure survives only as a stderr traceback. In these lock tests
    that silently converts an infrastructure failure into a false correctness
    verdict — a worker that dies on ``filelock.Timeout`` simply contributes no
    writes, so the counter/key assertions below report a "lost update" that
    never happened. Collecting the exceptions and re-raising keeps the two
    diagnoses distinguishable.

    The catch is deliberately ``BaseException``, not ``Exception``. Pytest's own
    outcome signals — ``pytest.fail()`` -> ``Failed``, ``pytest.skip()`` ->
    ``Skipped`` — derive from ``OutcomeException(BaseException)`` precisely so
    that stray ``except Exception`` clauses cannot swallow them. Narrowing here
    would re-open this helper's own failure mode for the most natural way to
    assert from inside a worker.
    """
    errors: list[BaseException] = []
    errors_lock = threading.Lock()

    def guarded(worker: Callable[[], None]) -> Callable[[], None]:
        def _run() -> None:
            try:
                worker()
            # Broad by design (see docstring); every capture is re-raised below.
            except BaseException as exc:
                with errors_lock:
                    errors.append(exc)

        return _run

    threads = [threading.Thread(target=guarded(w)) for w in workers]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    if errors:
        raise errors[0]


def test_run_workers_propagates_worker_exception() -> None:
    """A failing worker must surface as its own exception, not as a silent no-op.

    This is the guard for the CI flake ``_run_workers`` was written for: a
    worker dying on ``filelock.Timeout`` was invisible to ``join()``, so the
    concurrency assertions below reported a lost update instead of the timeout.
    """

    def raises_timeout() -> None:
        raise Timeout("some.lock")

    def succeeds() -> None:
        return None

    with pytest.raises(Timeout):
        _run_workers([succeeds, raises_timeout])


def test_run_workers_propagates_base_exception() -> None:
    """Propagation must survive a ``BaseException`` that is not an ``Exception``.

    Pytest's outcome signals (``pytest.fail`` -> ``Failed``, ``pytest.skip`` ->
    ``Skipped``) sit on ``OutcomeException(BaseException)`` specifically so a
    blanket ``except Exception`` cannot eat them. If ``_run_workers`` narrowed
    its catch, a worker calling ``pytest.fail(...)`` would vanish exactly the
    way a worker's ``filelock.Timeout`` used to.
    """

    class _WorkerSignal(BaseException):
        """Stands in for ``OutcomeException`` — deliberately not an ``Exception``."""

    def raises_base_exception() -> None:
        raise _WorkerSignal("not an Exception subclass")

    with pytest.raises(_WorkerSignal):
        _run_workers([raises_base_exception])

    # The real motivating case, exercised through pytest's own API.
    # ``pytest.fail.Exception`` is the public handle on ``Failed``, so this
    # stays out of the private ``_pytest`` namespace.
    def calls_pytest_fail() -> None:
        pytest.fail("worker asserted from inside a thread")

    assert not issubclass(pytest.fail.Exception, Exception)  # the whole point
    with pytest.raises(pytest.fail.Exception):
        _run_workers([calls_pytest_fail])


def test_public_shim_is_same_callable() -> None:
    """`notebooklm.io.atomic_update_json` must re-export the private symbol."""
    assert atomic_update_json is atomic_update_json_private


def test_creates_file_from_empty(tmp_path: Path) -> None:
    """If the target file does not exist, the mutator is called with ``{}``."""
    target = tmp_path / "state.json"

    received: list[dict] = []

    def mutator(current: dict) -> dict:
        received.append(dict(current))
        current["new_key"] = "new_value"
        return current

    atomic_update_json(target, mutator)

    assert received == [{}]
    assert json.loads(target.read_text(encoding="utf-8")) == {"new_key": "new_value"}


def test_empty_mutator_preserves_file(tmp_path: Path) -> None:
    """A no-op mutator must round-trip existing data unchanged."""
    target = tmp_path / "state.json"
    payload = {"a": 1, "b": [2, 3], "c": {"nested": True}}
    target.write_text(json.dumps(payload), encoding="utf-8")

    atomic_update_json(target, lambda d: d)

    assert json.loads(target.read_text(encoding="utf-8")) == payload


def test_mutator_adds_key(tmp_path: Path) -> None:
    """Mutator that adds a key — readback confirms the new key is persisted."""
    target = tmp_path / "state.json"
    target.write_text(json.dumps({"existing": "value"}), encoding="utf-8")

    def add_key(current: dict) -> dict:
        current["added"] = "yes"
        return current

    atomic_update_json(target, add_key)

    assert json.loads(target.read_text(encoding="utf-8")) == {
        "existing": "value",
        "added": "yes",
    }


def test_mutator_removes_key(tmp_path: Path) -> None:
    target = tmp_path / "state.json"
    target.write_text(json.dumps({"keep": 1, "remove": 2}), encoding="utf-8")

    def drop(current: dict) -> dict:
        del current["remove"]
        return current

    atomic_update_json(target, drop)

    assert json.loads(target.read_text(encoding="utf-8")) == {"keep": 1}


def test_concurrent_threads_no_lost_update(tmp_path: Path) -> None:
    """CRITICAL: two threads mutating disjoint keys must both win.

    Without the lock, the read-modify-write sequence has a window where
    thread B reads the file before thread A's write commits — B then writes
    a payload missing A's key. With ``atomic_update_json``, the file lock
    serializes the entire sequence so both keys land in the final state.
    """
    target = tmp_path / "state.json"
    # Pre-create the file so neither thread takes the "doesn't exist" branch.
    target.write_text(json.dumps({"seed": True}), encoding="utf-8")

    barrier = threading.Barrier(2, timeout=_BARRIER_TIMEOUT_SECONDS)

    def make_mutator(key: str, value: str):
        def _mutator(current: dict) -> dict:
            # Sleep inside the critical section to widen the window where a
            # lost update would happen if the lock weren't held.
            time.sleep(0.05)
            current[key] = value
            return current

        return _mutator

    def make_worker(key: str, value: str) -> Callable[[], None]:
        def _worker() -> None:
            barrier.wait()
            atomic_update_json(target, make_mutator(key, value))

        return _worker

    # Failures propagate — a worker that never wrote must not read as a lost
    # update. See ``_run_workers``.
    _run_workers([make_worker("alpha", "A"), make_worker("beta", "B")])

    final = json.loads(target.read_text(encoding="utf-8"))
    # Both writers' keys must be present — no lost update.
    assert final.get("alpha") == "A", f"thread A's update was lost: {final}"
    assert final.get("beta") == "B", f"thread B's update was lost: {final}"
    # Pre-existing data also preserved.
    assert final.get("seed") is True


@pytest.mark.timeout(_STRESS_TEST_TIMEOUT_SECONDS)
def test_many_concurrent_increments(tmp_path: Path) -> None:
    """Stress test: N threads each increment a counter K times.

    Final counter must equal N*K — any lost update would leave it lower.

    A shortfall here means one thing only: the lock failed to serialize a
    read-modify-write. It must never mean "a worker died before writing" — that
    ambiguity is what ``_run_workers`` and ``_STRESS_LOCK_TIMEOUT_SECONDS``
    exist to remove.
    """
    target = tmp_path / "counter.json"
    target.write_text(json.dumps({"count": 0}), encoding="utf-8")

    n_threads = 4
    increments_per_thread = 10

    def increment(current: dict) -> dict:
        current["count"] = int(current.get("count", 0)) + 1
        return current

    def worker() -> None:
        for _ in range(increments_per_thread):
            atomic_update_json(target, increment, timeout=_STRESS_LOCK_TIMEOUT_SECONDS)

    _run_workers([worker] * n_threads)

    final = json.loads(target.read_text(encoding="utf-8"))
    assert final["count"] == n_threads * increments_per_thread, (
        f"lost updates detected: expected {n_threads * increments_per_thread}, got {final['count']}"
    )


@pytest.mark.skipif(sys.platform == "win32", reason="POSIX permission semantics")
def test_chmod_0o600_after_update(tmp_path: Path) -> None:
    target = tmp_path / "secret.json"
    atomic_update_json(target, lambda d: {**d, "k": "v"})
    assert target.stat().st_mode & 0o777 == 0o600


@pytest.mark.skipif(sys.platform == "win32", reason="POSIX permission semantics")
def test_chmod_override(tmp_path: Path) -> None:
    target = tmp_path / "rw.json"
    atomic_update_json(target, lambda d: {**d, "k": "v"}, mode=0o644)
    assert target.stat().st_mode & 0o777 == 0o644


def test_timeout_raises_when_lock_held(tmp_path: Path) -> None:
    """If another process holds the lock past ``timeout``, raise Timeout."""
    target = tmp_path / "state.json"
    lock_path = target.with_suffix(target.suffix + ".lock")

    # Acquire the lock from the test thread; call expects to time out fast.
    holder = FileLock(str(lock_path))
    holder.acquire()
    try:
        with pytest.raises(Timeout):
            atomic_update_json(target, lambda d: d, timeout=0.1)
    finally:
        holder.release()

    # Once released, a normal call succeeds — proves the lock was the cause.
    atomic_update_json(target, lambda d: {**d, "ok": True}, timeout=1.0)
    assert json.loads(target.read_text(encoding="utf-8")) == {"ok": True}


def test_creates_parent_directory(tmp_path: Path) -> None:
    """If the parent directory doesn't exist, ``atomic_update_json`` creates it."""
    target = tmp_path / "nested" / "deep" / "state.json"
    atomic_update_json(target, lambda d: {**d, "k": "v"})
    assert target.exists()
    assert json.loads(target.read_text(encoding="utf-8")) == {"k": "v"}


def test_existing_non_dict_resets_to_empty(tmp_path: Path) -> None:
    """If the file contains valid JSON but not a dict (e.g., a list), the
    mutator receives ``{}`` rather than a malformed value.

    ``context.json`` and ``config.json`` are always object-shaped, so this
    defensive recovery matches the legacy behavior of the existing helpers.
    """
    target = tmp_path / "state.json"
    target.write_text(json.dumps([1, 2, 3]), encoding="utf-8")

    received: list[dict] = []

    def mutator(current: dict) -> dict:
        received.append(dict(current))
        return {"reset": True}

    atomic_update_json(target, mutator)
    assert received == [{}]
    assert json.loads(target.read_text(encoding="utf-8")) == {"reset": True}


def test_corrupt_json_raises_by_default(tmp_path: Path) -> None:
    """``recover_from_corrupt=False`` (default) propagates ``JSONDecodeError``."""
    target = tmp_path / "state.json"
    target.write_text("{ not json", encoding="utf-8")

    def mutator(current: dict) -> dict:
        current["should_not"] = "run"
        return current

    with pytest.raises(json.JSONDecodeError):
        atomic_update_json(target, mutator)

    # Nothing was written — the corrupt file is untouched (no unlink, no
    # overwrite). The caller decides what to do next.
    assert target.read_text(encoding="utf-8") == "{ not json"


def test_corrupt_json_recovers_with_flag(tmp_path: Path) -> None:
    """``recover_from_corrupt=True`` silently treats corrupt JSON as ``{}``."""
    target = tmp_path / "state.json"
    target.write_text("{ not json", encoding="utf-8")

    received: list[dict] = []

    def mutator(current: dict) -> dict:
        received.append(dict(current))
        current["recovered"] = True
        return current

    atomic_update_json(target, mutator, recover_from_corrupt=True)

    assert received == [{}]
    assert json.loads(target.read_text(encoding="utf-8")) == {"recovered": True}


def test_concurrent_corrupt_recovery_does_not_lose_valid_write(tmp_path: Path) -> None:
    """CRITICAL race: a peer's valid write must survive a corrupt-recovery call.

    This is the regression test for the PR #465 review threads. Previously,
    callers caught ``JSONDecodeError`` outside the lock, then unlinked and
    retried. A peer that wrote a valid payload between the raise and the
    unlink would lose its write to the unlink. With recovery inside the lock,
    only one of these orderings is possible per lock acquisition:

    * Peer wins the lock first → writes valid JSON → recovery caller sees
      the valid JSON and mutates from there (recovery branch never runs).
    * Recovery caller wins → reads corrupt → writes recovered payload →
      peer then sees the recovered payload (no data lost).

    Either way, the peer's key cannot vanish.
    """
    target = tmp_path / "state.json"
    # Start corrupt so the recovery thread has something to recover from.
    target.write_text("{ corrupt", encoding="utf-8")

    barrier = threading.Barrier(2, timeout=_BARRIER_TIMEOUT_SECONDS)

    def recovery_worker() -> None:
        barrier.wait()
        # Slight sleep so the peer has a real chance to race us.
        time.sleep(0.02)

        def _mutate(current: dict) -> dict:
            current["recovered_by"] = "A"
            return current

        atomic_update_json(target, _mutate, recover_from_corrupt=True)

    def peer_worker() -> None:
        barrier.wait()

        def _mutate(current: dict) -> dict:
            current["peer_wrote"] = "B"
            return current

        # Peer also opts into recovery — it doesn't care whether its read
        # sees corrupt content or the recovered dict.
        atomic_update_json(target, _mutate, recover_from_corrupt=True)

    # Failures propagate — a worker that never wrote must not read as a lost
    # update. See ``_run_workers``.
    _run_workers([recovery_worker, peer_worker])

    final = json.loads(target.read_text(encoding="utf-8"))
    # Both writers' keys must be present — neither lost the other's update.
    assert final.get("recovered_by") == "A", f"recovery worker lost: {final}"
    assert final.get("peer_wrote") == "B", f"peer worker lost: {final}"


# ---------------------------------------------------------------------------
# Lock-path derivation contract (#1220)
#
# ``atomic_update_json`` derives a NON-dotted ``<name>.lock`` sibling, which
# diverges from the canonical dotted ``.storage_state.json.lock`` sentinel that
# every ``storage_state.json`` mutator shares (``_storage_state_lock_path``,
# #1215). To stop a future caller silently acquiring the wrong lock and
# re-introducing the #1215 lost-update race, the helper rejects
# ``storage_state.json`` paths up front. The config/context callers keep their
# existing ``<name>.lock`` files unchanged.
# ---------------------------------------------------------------------------


# Casing variants are rejected too: on case-insensitive filesystems (macOS
# APFS/HFS+, Windows NTFS) ``Storage_State.json`` resolves to the same file as
# ``storage_state.json``, so a case-sensitive guard would let a variant slip
# past and re-introduce the divergent-lock race. The guard compares casefolded.
@pytest.mark.parametrize(
    "filename",
    ["storage_state.json", "Storage_State.json", "STORAGE_STATE.JSON"],
)
def test_rejects_storage_state_json_path(tmp_path: Path, filename: str) -> None:
    """A ``storage_state.json`` path (any casing) must be rejected with ``ValueError``.

    Its ``<name>.lock`` derivation diverges from the canonical dotted
    ``.storage_state.json.lock`` (``_storage_state_lock_path``), so routing it
    here would acquire the wrong lock — the exact #1215 footgun #1220 closes.
    """
    target = tmp_path / filename

    mutator_calls: list[dict] = []

    def mutator(current: dict) -> dict:
        mutator_calls.append(dict(current))
        return current

    with pytest.raises(ValueError, match="storage_state.json"):
        atomic_update_json(target, mutator)

    # The guard fires before any I/O: no file, no mutator call, and crucially
    # NEITHER lock variant is created on disk (for the given casing).
    assert mutator_calls == []
    assert not target.exists()
    assert not (tmp_path / f"{filename}.lock").exists()  # divergent (would-be)
    assert not (tmp_path / f".{filename}.lock").exists()  # canonical-shaped dotted


def test_rejection_holds_with_recover_flag(tmp_path: Path) -> None:
    """The guard also fires when ``recover_from_corrupt=True`` is requested."""
    target = tmp_path / "storage_state.json"
    target.write_text("{ corrupt", encoding="utf-8")

    with pytest.raises(ValueError, match="storage_state.json"):
        atomic_update_json(target, lambda d: d, recover_from_corrupt=True)

    # The pre-existing (corrupt) file is left untouched — no recovery write.
    assert target.read_text(encoding="utf-8") == "{ corrupt"


def test_rejection_matches_canonical_lock_helper(tmp_path: Path) -> None:
    """Cross-check: the rejected name is exactly the one whose canonical lock
    is the dotted sentinel, and that sentinel differs from this helper's
    ``<name>.lock`` derivation.
    """
    from notebooklm._auth.paths import _storage_state_lock_path

    target = tmp_path / "storage_state.json"
    canonical = _storage_state_lock_path(target)
    divergent = target.with_suffix(target.suffix + ".lock")

    # Sanity: the two derivations really are different files.
    assert canonical.name == ".storage_state.json.lock"
    assert divergent.name == "storage_state.json.lock"
    assert canonical != divergent

    # And the helper refuses to operate on this path at all.
    with pytest.raises(ValueError):
        atomic_update_json(target, lambda d: d)


@pytest.mark.parametrize("filename", ["config.json", "context.json"])
def test_allowed_paths_use_unchanged_nondotted_lock(tmp_path: Path, filename: str) -> None:
    """``config.json`` / ``context.json`` lock derivation is UNCHANGED.

    The guard only special-cases ``storage_state.json``; the legitimate callers
    keep acquiring their existing non-dotted ``<name>.lock`` sibling. We prove
    this by pre-acquiring that exact lock and asserting the call times out on
    it — i.e. it really is the file the helper contends on.
    """
    target = tmp_path / filename
    expected_lock = target.with_suffix(target.suffix + ".lock")
    assert expected_lock.name == f"{filename}.lock"  # non-dotted, unchanged

    holder = FileLock(str(expected_lock))
    holder.acquire()
    try:
        with pytest.raises(Timeout):
            atomic_update_json(target, lambda d: {**d, "k": "v"}, timeout=0.1)
    finally:
        holder.release()

    # After release the call succeeds and writes through the same lock file.
    atomic_update_json(target, lambda d: {**d, "ok": True}, timeout=1.0)
    assert json.loads(target.read_text(encoding="utf-8")) == {"ok": True}
    # The dotted sentinel was never created for these allowed names.
    assert not (tmp_path / f".{filename}.lock").exists()
