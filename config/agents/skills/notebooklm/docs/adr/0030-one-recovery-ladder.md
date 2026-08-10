# ADR-0030: One recovery ladder

## Status

Accepted (rolling out — refactor (c): c-PR1 lands the pure/off-loop loaders and
the loop-liveness gate; c-PR2 lands `single_flight.py` and folds cold-start
coalescing onto it (deleting the per-loop machinery same-PR); c-PR3 lands
in-process outcome-based re-mint coalescing; c-PR4 lands the opt-in mid-session
refresh-cmd rung (L2.5) plus the refresh-cmd logging/env hardening and the
`refresh_auth` join semantics; c-PR5 is docs + cleanup only).

Companion to [ADR-0029](0029-canonical-storage-writer.md) (refactor (b), the
single canonical `storage_state.json` writer). Where ADR-0029 unifies the
**write** side, this ADR unifies the **recovery/refresh** side.

## Context

The cookie/auth audit found the refresh/recovery surface split into **two
parallel universes** that had drifted apart:

- **Mid-session recovery** — middleware → executor → `AuthRefreshCoordinator` +
  `RefreshBudget`. Loop-bound by the ADR-0004 contract, it hands followers a
  shared `asyncio.Task` and has pinned task-identity / slot invariants. This
  composes soundly and is **not** the problem.
- **Cold-start** (`fetch_tokens*`) — implemented its **own** cross-loop
  coalescing (per-loop future maps + a `_REFRESH_GENERATIONS` generation
  counter in `refresh.py`; per-loop in-flight task maps + a settle loop and
  `_COLD_SUCCESS_GENERATIONS` epoch in `recovery.py`), took **no** cross-process
  lock around the `NOTEBOOKLM_REFRESH_CMD` subprocess, and its rung set diverged
  from the mid-session ladder.

Concrete defects this produced:

- [refresh-1 / HIGH#2] The cookie loaders did inline PSIDTS recovery — a
  synchronous ~15 s POST plus file I/O — from inside the load path, stalling the
  event loop of any async caller.
- [refresh-2] Refresh-cmd stampede: per-loop coalescing only, so N processes (or
  N loops with no shared registry) each spawned the subprocess.
- [refresh-4] `NOTEBOOKLM_REFRESH_CMD` was reachable only at cold start, never
  mid-session, so a long-lived server could not re-mint via the operator's
  command.
- [capture-3] Headless re-mint followers coalesced on the file **mtime**
  heuristic, so a follower could observe a stale/pre-wait drive cycle and report
  a false `SUCCESS`.
- [refresh-5] The keepalive poke throttle keyed on a non-canonicalised path, so
  two spellings of one profile throttled independently.

The cold-start coalescing logic was hand-rolled and duplicated across
`refresh.py` and `recovery.py`; every guarantee lived in comments and
whitebox-coupled tests rather than in one auditable core.

## Decision

Unify recovery around three moves: **pure/off-loop loaders**, a **single-flight
core** that formalises (not extracts) the existing cross-loop pattern, and **one
rung ladder** whose rung set is a per-entry-point policy flag. The
`AuthRefreshCoordinator` and the mid-session middleware are **deliberately left
untouched** (see the boundary below).

### Two loader layers, named distinctly (c-PR1)

```text
_load_cookies_pure(path)                 # inner: file I/O + validation ONLY,
                                         #        no network, EVER
build_httpx_cookies_from_storage(path)   # public wrapper: pure load +
                                         #        explicit recovery composition
```

The inline PSIDTS recovery is **extracted from the load path into the wrapper
bodies** (`load_auth_from_storage` in `_auth/tokens.py` and the `cookies.py`
wrapper). The pure loader raises `RequiredCookieValidationError` carrying a
closed-enum reason (`psidts_unroutable` | `missing_cookie`); the wrapper decides
whether to invoke recovery. Sync callers (CLI) keep the inline recovery
behaviour verbatim; async callers offload the wrapper via `asyncio.to_thread`,
so a slow recovery POST never runs on the event loop. The #2061
decline→retry-name-only fallback survives byte-for-byte (pinned by the 87 PSIDTS
tests, which pass unmodified). A loop-liveness gate test (< 50 ms stall with a
mocked slow recovery POST) locks the fix in.

### The single-flight core (`_auth/single_flight.py`, c-PR2)

`single_flight.py` is the **formalisation of the existing
`refresh.py` / `recovery.py` cross-loop pattern**, not an extraction from
`AuthRefreshCoordinator`. Two process-global facilities:

- **Flight registry** — one in-flight operation shared per **`(canonical
  storage path, rung policy)`** flight key (matching the shape of the registries
  it replaces: recovery keyed on `(path, allow_headless)`; refresh keyed on the
  path plus its refresh-cmd policy). A *leader* drives the work as an
  `asyncio.Task` on its own loop (held in a strong-ref set so the asyncio GC
  cannot collect it) and mirrors completion into a
  `concurrent.futures.Future`. *Followers* on **any** loop bridge to that future
  via `asyncio.shield(asyncio.wrap_future(f))` with a settle-before-propagate
  loop — plain `wrap_future` would let one cancelled follower detonate its
  siblings, and `run_coroutine_threadsafe` is deliberately ruled out (a follower
  never runs the leader's coroutine).
- **Success epoch** — one process-global counter **per canonical storage PATH**
  (path only, **not** per policy: a late refresh-cmd waiter must observe a
  completed flight's success regardless of which policy key that flight ran
  under; per-policy epochs would send it to a redundant subprocess). It
  relocates the `_REFRESH_GENERATIONS` semantics from `refresh.py` and preserves
  all **four pinned guarantees**: (1) late-waiter skip
  (capture-epoch-before-wait, and — via `claim_if_epoch_current` — the epoch
  compare and the flight claim happen under a **single** lock hold, so a sibling
  that bumps and prompt-pops in between cannot trick a waiter into a second
  subprocess); (2) bump on subprocess **success only** (a failure leaves waiters
  retrying); (3) a settled future stays inspectable for the cancel/settle race
  (#621); (4) no phantom bump on cancel-before-register, including the
  warm-registry variant (#816).

One `threading.Lock` guards **only** the brief synchronous claim / registry /
epoch mutations; it is never held across an `await` or a subprocess. Retention
is **value-free**: the registry stores only flight bookkeeping and integer
epochs — a flight's jar-bearing result (e.g. `ColdRecoveryResult`) rides the
per-flight future and is prompt-popped the moment the flight settles, so no new
credential-lifetime surface appears (the same value-free contract ADR-0029 pins
for write outcomes).

Consumer-side policy stays with the consumers: `recovery.py` keeps its per-loop
revalidate-on-bump epoch (`_COLD_SUCCESS_GENERATIONS`) and per-loop mutation
lock — deliberately **not** promoted to cross-loop, because that would change
the fresh-loop-runs-full-ladder behaviour.

### One ladder, rung availability as policy

```text
L1 homepage refresh
  → L2 RotateCookies / PSIDTS rotation
  → L2.5 refresh-cmd            (NEW rung; promoted from cold-only [refresh-4])
  → L3 headless re-mint
  → L4 master-token re-mint
```

Rung numbering follows the code's existing convention (L2 is already
RotateCookies). Rung availability is a **policy flag per entry point**:
`fetch_tokens_passive` gets none, CLI login gets none, client cold-start /
mid-session get the rungs as configured.

- **Cross-process exclusion (c-PR2):** the refresh-cmd rung (L2.5) takes a
  **per-path flock** before spawning the subprocess (the keepalive-rotation
  pattern), closing [refresh-2]. The re-mint rungs (L3/L4) deliberately do
  **not** — cross-process re-mints stay each-own-browser by design.
- **In-process re-mint coalescing (c-PR3):** the leader publishes a **typed,
  closed-enum outcome** (`SUCCESS` / `FAILED_<cause>` / `LOGIN_REQUIRED`, never
  free-text reason strings) through the per-path drive lock, so followers stop
  coalescing on the mtime heuristic and the false-`SUCCESS` [capture-3] becomes
  unrepresentable. No sidecar / on-disk artifact is introduced.
- **Canonical poke key (c-PR2):** one `canonical_storage_key(path)` helper backs
  the throttle map, the poke lock, and the flock derivation, closing
  [refresh-5].

### Mid-session refresh-cmd rung (L2.5), opt-in for one release (c-PR4)

`refresh_auth_session`'s ladder gains L2.5, gated **opt-in for one release**
behind `NOTEBOOKLM_REFRESH_CMD_MIDSESSION=1` (de-risks operators whose commands
assume cold-start-only invocation; flips to default-on the following release).
Because promoting the rung into long-lived servers widens exposure, c-PR4
bundles security hardening:

- The refresh-cmd DEBUG log drops raw `stdout`/`stderr` `%r` dumps → basename +
  exit code + byte counts by default; full captured output only behind the
  explicit `NOTEBOOKLM_REFRESH_CMD_LOG_OUTPUT=1` opt-in.
- The subprocess environment pops **all** first-party secret / credential vars
  before spawn (`NOTEBOOKLM_AUTH_JSON`, `NOTEBOOKLM_SERVER_TOKEN`,
  `NOTEBOOKLM_SERVER_TOKEN_FILE`, `NOTEBOOKLM_MCP_TOKEN`,
  `NOTEBOOKLM_MCP_OAUTH_PASSWORD`, `NOTEBOOKLM_MCP_OAUTH_STATE_PATH`), not just
  `NOTEBOOKLM_AUTH_JSON`, so a
  long-lived server's own auth secret cannot leak into every refresh subprocess
  and its grandchildren (`/proc/<pid>/environ`).

Explicit `client.refresh_auth()` routes through the coordinator's
`await_refresh` with **defined join semantics** — **join-then-rerun, implemented
caller-side**: a wider-policy caller (`allow_headless=True`) joins whatever
flight is in progress and, if that flight fails, re-runs its own flight with its
full rung policy, so it never silently loses its L3 rung. The coordinator keeps
its single unkeyed task slot; its internals are untouched.

### Env-var, logging, and read consolidation (c-PR5)

- `NOTEBOOKLM_AUTH_JSON` is read through **one** helper,
  `notebooklm._auth.paths.resolve_auth_json_env()`. Before it, ~7 call sites
  spelled the check by hand and disagreed on presence-vs-truthiness (the #2057 /
  #2083 drift class). The helper is presence-based (unset ⇒ `None`; set ⇒ the
  value, so a set-but-empty value counts as *selected* and never falls through
  to a profile file); the one consumer that parses the payload
  (`_load_storage_state`) raises the "set but empty" configuration error. The
  presence-only callers (path resolvers, PSIDTS recovery, header routing, the
  cookie-save skip) route through the same helper and stay behaviour-identical.
- `_auth/_browser_cookie_filter.py` logs to `notebooklm.auth`
  (not `__name__`) so its dropped-cookie / malformed-row warnings reach the
  documented auth logger (core-F10 / ADR-0016).

### Boundary — what this ADR does NOT touch

- **`AuthRefreshCoordinator` internals** — loop-bound by ADR-0004, shared-Task
  followers, pinned slot invariants. Any future composition with
  `single_flight.py` is its own PR with its own test-migration plan (plan §c.7).
- **The mid-session middleware chain** — unchanged; only the ladder's rung set
  (L2.5) and the refresh-cmd hardening are added.
- **Ladder rung internals** (capture, minting) — unchanged.
- **No public API signature changes** to `fetch_tokens*` / `refresh_auth`; the
  only new env vars are the two documented additions
  (`NOTEBOOKLM_REFRESH_CMD_MIDSESSION`, `NOTEBOOKLM_REFRESH_CMD_LOG_OUTPUT`).
- **No cross-process re-mint coalescing** and **no new on-disk artifacts**
  (plan §c.5); **no legacy-shape retirement** (candidate refactor (d)).

## Consequences

- The load path never blocks the event loop on recovery; async callers offload a
  network-free-by-construction pure loader plus an explicit recovery wrapper.
- Cross-loop coalescing lives in **one** auditable core with its four guarantees
  expressed in code, not comments. The per-loop future maps and generation dicts
  in `refresh.py` / `recovery.py` are deleted in the same PR that adds the core,
  so a revert restores them cleanly.
- The refresh-cmd subprocess is serialised across processes (per-path flock),
  killing the stampede; re-mint coalescing is outcome-based, killing the
  false-`SUCCESS`.
- The refresh-cmd rung is reachable mid-session (opt-in for one release), with
  tighter default logging and full secret-env scrubbing for server contexts.
- Two whitebox pinning suites (`test_refresh_lock_registry.py`,
  `test_refresh_cmd_race.py`) were **migrated** in c-PR2 — each pinned guarantee
  (the four epochs above, plus lock identity) is re-expressed against
  `single_flight.py`'s surface, and the five underscore-private facade
  test-bindings for the deleted machinery are removed (not part of the supported
  facade surface).

## Alternatives considered

- **Extract the core from `AuthRefreshCoordinator`.** Rejected: the coordinator
  is loop-bound (ADR-0004) and hands followers a shared `asyncio.Task` with
  pinned task-identity invariants; a cross-loop core cannot inherit those
  without breaking the mid-session contract. The core instead formalises the
  *other* (cold-start) pattern and leaves the coordinator alone.
- **Per-policy success epoch.** Rejected: a late waiter under one policy key
  must observe a completed flight's success under a different policy key, or it
  spawns a redundant subprocess. The epoch is per canonical PATH; the flight
  registry is per `(path, policy)`.
- **Cross-process re-mint coalescing (outcome sidecar).** Deferred (design
  archived in the plan's Appendix A): re-mints each own their browser by design,
  and a shared outcome record adds a credential-lifetime surface and a
  crash-consistency protocol not justified by the current failure modes.
- **Land the mid-session rung default-on.** Rejected for the first release:
  operators whose refresh commands assume cold-start-only invocation would be
  surprised inside a long-lived server. Opt-in for one release, then default-on.
- **A raising `resolve_auth_json_env()` helper.** Rejected: the deliberate
  #2057 / #2083 contract is that path resolvers return `None` (env-mode) on a
  set-but-empty value while the loader raises "set but empty". A raising helper
  would move the error off the loader and break that tested contract, so the
  helper is presence-based and the single consumer raises.

## Related references

- [Architecture](../architecture.md) — layered design and the `_auth/` file
  index.
- [ADR-0029](0029-canonical-storage-writer.md) — the write-side companion
  (single canonical `storage_state.json` writer).
- [ADR-0004](0004-loop-affinity-contract.md) — the loop-affinity contract that
  keeps `AuthRefreshCoordinator` out of scope here.
- [ADR-0016](0016-auth-identity-and-core-logger-compatibility.md) — the
  `notebooklm.auth` logger namespace the browser-cookie filter now targets.
- [ADR-0023](0023-master-token-headless-auth.md) — the L4 master-token re-mint
  rung.
