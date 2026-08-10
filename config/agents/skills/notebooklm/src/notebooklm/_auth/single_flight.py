"""Cross-loop single-flight coalescing + a per-path success epoch.

This module FORMALIZES the cross-loop coalescing pattern that used to live,
hand-rolled and duplicated, in :mod:`notebooklm._auth.refresh` (per-loop
future map + ``_REFRESH_GENERATIONS`` counter) and
:mod:`notebooklm._auth.recovery` (per-loop in-flight task maps + settle loop).
It is **not** an extraction from ``AuthRefreshCoordinator``: that coordinator
is loop-bound by ADR-0004 contract, hands followers a shared ``asyncio.Task``,
and has its own pinned task-identity/slot invariants — it is deliberately left
untouched (plan §c.7).

Two facilities, both process-global:

* **Flight registry** — one in-flight operation shared per ``flight_key``. A
  *leader* drives the work as an ``asyncio.Task`` on its own loop (held in a
  strong-ref set so the asyncio GC cannot collect it) and mirrors completion
  into a :class:`concurrent.futures.Future`. *Followers* on ANY event loop
  bridge to that future via ``asyncio.shield(asyncio.wrap_future(f))`` with a
  settle-before-propagate loop, so a single follower's cancellation cannot
  detonate its siblings and a cross-loop caller never has to run the leader's
  coroutine itself (``run_coroutine_threadsafe`` is deliberately ruled out).

* **Success epoch** — one process-global counter per canonical storage PATH.
  It relocates the ``_REFRESH_GENERATIONS`` semantics from ``refresh.py``: a
  caller captures the epoch *before* it waits, and after its coalesced work
  either succeeds (the worker bumps the epoch) or fails (no bump, so waiters
  retry). A late waiter whose captured epoch is already stale skips its own
  subprocess and just reloads the freshly-written storage — and via
  :func:`claim_if_epoch_current` that epoch compare and the flight claim happen
  under a SINGLE lock hold (compare-under-exclusion), so a sibling that bumps
  and prompt-pops its flight in between can never trick the waiter into spawning
  a redundant second subprocess.

Threading discipline: one :class:`threading.Lock` (``_REGISTRY_LOCK``) guards
ONLY the brief synchronous claim/registry/epoch mutations. It is NEVER held
across an ``await`` or a subprocess. ``concurrent.futures.Future`` completion
is set from the leader's loop (its task done-callback) and is safe to observe
from any other loop through ``asyncio.wrap_future``.

Value-free retention: the registry stores only flight bookkeeping and integer
epochs. A flight's *result* (e.g. cold recovery's jar-bearing
``ColdRecoveryResult``) rides the per-flight future and is dropped from the
registry the moment the flight settles (prompt-pop); it is never copied into a
long-lived registry structure, so no new credential-lifetime surface appears.
"""

from __future__ import annotations

import asyncio
import concurrent.futures
import contextlib
import logging
import threading
from collections.abc import Callable, Coroutine, Hashable
from dataclasses import dataclass, field
from typing import Any, Generic, TypeVar

logger = logging.getLogger("notebooklm.auth")

T = TypeVar("T")

# A flight is keyed per (canonical storage path, rung policy) — matching the
# shape of the registries this core replaces (recovery keyed on
# ``(path, allow_headless)``; refresh keyed on the path plus its single
# refresh-cmd policy). The policy component is any hashable discriminator.
FlightKey = tuple[str, Hashable]


@dataclass
class Flight(Generic[T]):
    """One in-flight operation shared across event loops.

    ``bridge`` is a :class:`concurrent.futures.Future` mirroring the leader
    task's terminal state; followers on any loop await it via
    ``asyncio.wrap_future``. ``task`` is the leader's ``asyncio.Task`` (bound to
    the leader's loop) and is populated immediately after construction, under
    the registry lock, before any follower can observe the flight.
    """

    bridge: concurrent.futures.Future[T] = field(default_factory=concurrent.futures.Future)
    task: asyncio.Task[T] | None = None


# --- Process-global state ----------------------------------------------------
# ONE threading.Lock guards the registry, the strong-ref task set, and the
# success-epoch map. It is held only for brief synchronous sections (claim /
# settle / epoch read-modify-write) and NEVER across an await or subprocess.
_REGISTRY_LOCK = threading.Lock()
_FLIGHTS: dict[FlightKey, Flight[Any]] = {}
# Strong references to leader tasks so the asyncio GC does not collect a
# subprocess-driving task whose only awaiter got cancelled. Both ``set.add``
# (in ``_claim``) and ``set.discard`` (in the ``_on_done`` callback) mutate this
# set under ``_REGISTRY_LOCK`` — it is part of the state that lock guards, so the
# discipline holds under free-threaded CPython, not merely by GIL atomicity. The
# task self-removes via ``add_done_callback``.
_LEADER_TASKS: set[asyncio.Task[Any]] = set()
# Process-global per-canonical-PATH success counter. Keyed per path only (NOT
# per (path, policy)): a late refresh-cmd waiter must observe a completed
# flight's success regardless of which policy key that flight ran under, else
# it would fire a redundant subprocess against just-refreshed storage.
_SUCCESS_EPOCHS: dict[str, int] = {}


def read_success_epoch(path_key: str) -> int:
    """Return the current success epoch for ``path_key`` (0 if never bumped)."""
    with _REGISTRY_LOCK:
        return _SUCCESS_EPOCHS.get(path_key, 0)


def note_success(path_key: str) -> None:
    """Bump the success epoch for ``path_key``.

    Called by a leader worker ONLY after its underlying operation actually
    succeeded (e.g. the refresh-cmd subprocess exited zero). Because the flight
    registry admits a single active flight per key, bumps are serialized and a
    plain increment is race-free under the lock.
    """
    with _REGISTRY_LOCK:
        _SUCCESS_EPOCHS[path_key] = _SUCCESS_EPOCHS.get(path_key, 0) + 1


def claim(
    flight_key: FlightKey, factory: Callable[[], Coroutine[Any, Any, T]]
) -> tuple[bool, Flight[T]]:
    """Claim leadership for ``flight_key`` or join the in-flight leader.

    Returns ``(is_leader, flight)``. The leader path creates the driving
    ``asyncio.Task`` (on the caller's running loop) and registers it under the
    lock, so a concurrent claimer — on this loop or any other — deterministically
    observes the registered flight and becomes a follower. Exactly one leader
    exists per key at a time.

    Must be called from a coroutine (a running loop is required to create the
    leader task). The lock is held only for the synchronous claim + task
    creation; ``factory`` is invoked to build the coroutine but the task does
    not run until the caller next awaits.

    Callers that layer a success epoch on top (refresh-cmd) should use
    :func:`claim_if_epoch_current` so the epoch compare and the flight claim are
    a SINGLE atomic lock hold; this bare ``claim`` has no epoch guard and never
    skips (used by cold recovery / master-token, which carry no epoch).
    """
    is_leader, flight = _claim(flight_key, factory, path_key=None, epoch_before=None)
    # No epoch guard was supplied, so the skip branch is unreachable here.
    assert flight is not None
    return is_leader, flight


def claim_if_epoch_current(
    flight_key: FlightKey,
    factory: Callable[[], Coroutine[Any, Any, T]],
    *,
    path_key: str,
    epoch_before: int,
) -> tuple[bool, Flight[T]] | None:
    """Epoch-aware :func:`claim`: skip if the success epoch already advanced.

    Compare-and-claim under a SINGLE ``_REGISTRY_LOCK`` hold. Returns ``None``
    (a "skip" signal — no leader task created) when
    ``_SUCCESS_EPOCHS[path_key] > epoch_before``, i.e. a cross-loop sibling
    finished its subprocess and bumped the epoch between the caller's
    ``read_success_epoch`` and this claim. Because the compare and the
    check-and-insert share one lock acquisition, a sibling can no longer
    interleave a ``note_success`` + prompt-pop between them and trick this caller
    into spawning a redundant second subprocess — this is the plan's
    "compare-under-exclusion" late-waiter skip.

    Otherwise behaves exactly like :func:`claim`, returning ``(is_leader,
    flight)``.
    """
    is_leader, flight = _claim(flight_key, factory, path_key=path_key, epoch_before=epoch_before)
    if flight is None:
        # Epoch advanced under exclusion — skip signal.
        return None
    return is_leader, flight


def _claim(
    flight_key: FlightKey,
    factory: Callable[[], Coroutine[Any, Any, T]],
    *,
    path_key: str | None,
    epoch_before: int | None,
) -> tuple[bool, Flight[T] | None]:
    loop = asyncio.get_running_loop()
    with _REGISTRY_LOCK:
        # Compare-under-exclusion: if an epoch guard was supplied and a sibling
        # has SUCCEEDED since the caller captured ``epoch_before``, skip before
        # touching the registry (no leader task, no redundant subprocess).
        if (
            path_key is not None
            and epoch_before is not None
            and _SUCCESS_EPOCHS.get(path_key, 0) > epoch_before
        ):
            return False, None
        existing = _FLIGHTS.get(flight_key)
        # A settled flight left in the registry is overwritable: the next cycle
        # replaces it. (The settle callback also pops it; both paths agree.)
        if existing is not None and not existing.bridge.done():
            return False, existing
        flight = Flight[T]()
        task = loop.create_task(factory())
        flight.task = task
        _FLIGHTS[flight_key] = flight
        _LEADER_TASKS.add(task)

    def _on_done(settled: asyncio.Task[T]) -> None:
        # Order: mirror the terminal state onto the bridge (waking followers),
        # then drop the strong ref and prompt-pop the registry slot.
        # The strong-ref set is part of the state ``_REGISTRY_LOCK`` guards, so
        # the discard takes the lock too (``.add`` in ``_claim`` holds it) —
        # keeping the module's "one lock guards the registry, task set, and epoch
        # map" invariant intact under free-threaded CPython, not just GIL-atomic.
        # The critical section is a single ``set.discard`` with no await inside;
        # the callback runs on the leader's loop, so this brief plain-lock hold
        # cannot deadlock.
        with _REGISTRY_LOCK:
            _LEADER_TASKS.discard(settled)
        _mirror(settled, flight)
        _pop(flight_key, flight)
        # Retrieve a terminal exception so the (possibly awaiter-less) bridge is
        # not GC'd with an unretrieved exception — keeps a leader that fails
        # under caller-cancellation from emitting a stray traceback.
        if flight.bridge.done() and not flight.bridge.cancelled():
            with contextlib.suppress(BaseException):
                flight.bridge.exception()

    task.add_done_callback(_on_done)
    return True, flight


def _mirror(task: asyncio.Task[Any], flight: Flight[Any]) -> None:
    """Copy the settled leader task's terminal state into the bridge future.

    Runs on the leader's loop (task done-callback); setting a
    ``concurrent.futures.Future`` result/exception from there is observable
    from any other loop via ``asyncio.wrap_future``. A cancelled leader task is
    surfaced to followers as a ``CancelledError`` *exception* on the bridge
    (rather than cancelling the bridge) so ``asyncio.wrap_future`` delivers it
    as an ordinary awaited outcome.

    Leader-cancellation note (CodeRabbit #3): a follower on a DIFFERENT loop then
    observes that ``CancelledError`` and, via :func:`await_flight`, re-raises it
    as though the follower itself were cancelled — it does NOT fall through to the
    fresh-leader retry path. This is deliberate and safe: no PRODUCTION code
    calls ``.cancel()`` on a ``_LEADER_TASKS`` member (only a coverage test does,
    to exercise this very path), so a leader task is cancelled ONLY on event-loop
    / interpreter TEARDOWN. In that terminal
    condition the shared work is genuinely gone; a same-loop follower is being
    torn down too (correctly cancelled), and the rare cross-loop case degrades to
    one aborted attempt that the caller's normal error handling surfaces — never a
    hang and never a duplicate subprocess (the flight is prompt-popped, so the
    next fresh call simply claims a new leader). Distinguishing leader- from
    caller-cancellation would need a separate non-``CancelledError`` bridge signal
    threaded through every ``await_flight`` consumer (incl. recovery's one-shot
    callers), which is not warranted for a teardown-only edge.
    """
    bridge = flight.bridge
    if bridge.done():
        return
    if task.cancelled():
        bridge.set_exception(asyncio.CancelledError())
        return
    exc = task.exception()
    if exc is not None:
        bridge.set_exception(exc)
    else:
        bridge.set_result(task.result())


def _pop(flight_key: FlightKey, flight: Flight[Any]) -> None:
    """Remove the settled flight from the registry (prompt-pop retention).

    Only pops if the slot still holds *this* flight — a newer leader may have
    already replaced it. The per-flight future keeps the result alive for
    followers that still hold a reference; nothing result-bearing lingers in the
    process-global registry.
    """
    with _REGISTRY_LOCK:
        if _FLIGHTS.get(flight_key) is flight:
            del _FLIGHTS[flight_key]


async def await_flight(flight: Flight[T]) -> T:
    """Await a flight from any loop, settling before propagating cancellation.

    Bridges the leader's :class:`concurrent.futures.Future` onto the caller's
    loop via ``asyncio.wrap_future`` and shields it: the caller's own
    cancellation must NOT cancel the shared work. On caller cancellation we keep
    re-awaiting until the flight settles (so a leader's cancelled awaiter does
    not release exclusion mid-subprocess and let a duplicate spawn), then
    re-raise ``CancelledError`` — caller cancellation always wins. Otherwise the
    flight's result is returned and its exception (including a leader-cancelled
    ``CancelledError`` delivered as a bridge exception) propagates to the
    awaiter.

    In-tree precedent: ``recovery.py``'s ``_await_shared_task`` (this replaces
    it, generalized from an ``asyncio.Task`` to a cross-loop future bridge).
    """
    # ONE wrapper future over the shared bridge (``asyncio.wrap_future``),
    # re-shielded across every await. ``asyncio.shield`` allocates a fresh outer
    # future per call, so under repeated rapid cancellation the settle loop below
    # re-shields ``wrapped`` once per retry — but the single wrapper over the
    # shared bridge is never re-created, and — the critical safety property — the
    # bridge is NEVER cancelled out from under sibling followers, even on a SECOND
    # cancellation during the settle window (``shield`` absorbs the repeated
    # cancel; the un-shielded form would chain ``bridge.cancel()`` and detonate
    # every sibling — #621).
    wrapped = asyncio.wrap_future(flight.bridge)
    try:
        return await asyncio.shield(wrapped)
    except asyncio.CancelledError:
        # Caller-side cancellation (or a bridge that resolved with a
        # CancelledError exception). Settle-before-propagate: keep re-awaiting
        # the SHIELDED shared work until it is done, so a duplicate never spawns
        # and siblings still see the leader's real outcome, then propagate our
        # cancellation. ``shield`` means a repeated cancel raises here without
        # cancelling the bridge.
        while not flight.bridge.done():
            try:
                await asyncio.shield(wrapped)
            except asyncio.CancelledError:
                if flight.bridge.done():
                    break
                continue
            except BaseException:  # noqa: BLE001 - settle before propagating
                break

        # Drain the settled wrapper so it is not GC'd with an unretrieved
        # exception (stray "Future exception was never retrieved" in CI logs).
        # Cross-loop (CodeRabbit #6): the bridge can be done on the LEADER's loop
        # while ``wrapped`` is still PENDING on this loop (``wrap_future`` resolves
        # it via ``call_soon_threadsafe``), so a bare ``if wrapped.done()`` check
        # here would skip the drain and leak the exception. Drain now if already
        # done, else attach a done-callback that retrieves it whenever it lands —
        # we still re-raise our cancellation immediately below.
        def _drain(fut: asyncio.Future[Any]) -> None:
            if not fut.cancelled():
                with contextlib.suppress(BaseException):
                    fut.result()

        if wrapped.done():
            _drain(wrapped)
        else:
            wrapped.add_done_callback(_drain)
        raise


def _reset_for_tests() -> None:
    """Clear all process-global single-flight state (test helper)."""
    with _REGISTRY_LOCK:
        _FLIGHTS.clear()
        _LEADER_TASKS.clear()
        _SUCCESS_EPOCHS.clear()
