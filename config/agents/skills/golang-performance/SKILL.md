---
name: golang-performance
description: >-
  Use after a profile or representative benchmark identifies a Go bottleneck.
  Diagnose and validate allocation, CPU, memory, runtime, I/O, concurrency, or
  caching changes. Do not use as a substitute for measurement or correctness
  testing.
compatibility: Requires a Go toolchain. Statistical comparison can use benchstat.
---

# Go performance

Load [golang](../golang/SKILL.md) and
[golang-testing](../golang-testing/SKILL.md). Follow repository commands and
supported Go versions.

## Require evidence

Establish:

1. the user-visible problem and target metric
2. the workload, input distribution, and environment
3. the profile or benchmark that locates the cost
4. the correctness tests that protect behavior
5. the acceptable trade-offs in latency, throughput, memory, and maintenance.

If evidence does not identify a bottleneck, propose the smallest measurement
that will. Do not present a speculative optimization as a fix.

Use the profile that matches the suspected resource:

| Evidence | Use |
| --- | --- |
| CPU profile | on-CPU hot functions |
| allocation or heap profile | allocation rate and retained memory |
| mutex or block profile | lock and blocking contention |
| goroutine profile or trace | waits, leaks, scheduling, and I/O |
| execution trace | scheduler, network, and GC interactions |
| production trace | database and remote-service latency |

Rule out external bottlenecks. Local allocation changes will not fix latency
dominated by a database, network, or downstream service.

## Run a controlled cycle

1. Run relevant correctness tests.
2. Record multiple baseline samples.
3. Form one hypothesis from the evidence.
4. Change one variable.
5. Repeat the same samples on comparable hardware and load.
6. Compare distributions, not the best result.
7. Keep the change only if the target metric improves without an unacceptable
   regression.

Use the repository benchmark target first. Otherwise, a focused comparison can
use:

```sh
go test -run='^$' -bench='BenchmarkTarget$' -benchmem -count=10 ./path/to/pkg
```

Save baseline and candidate output in unique temporary files. Use `benchstat`
when available. If it is unavailable, report that the statistical comparison is
limited.

Do not benchmark competing candidates concurrently on shared hardware. Record
the Go version, relevant environment, command, sample count, and input.

## Select an intervention

Read only the reference that matches the measured cost:

- [memory.md](references/memory.md) for allocations, retention, pools, and
  layout
- [cpu.md](references/cpu.md) for CPU hot paths, inlining, and locality
- [io-networking.md](references/io-networking.md) for network, files, streaming,
  and serialization
- [runtime.md](references/runtime.md) for GC, memory limits, scheduling, and
  profile-guided optimization
- [caching.md](references/caching.md) for work avoidance, complexity, caching,
  and singleflight
- [observability.md](references/observability.md) for production measurement.

Treat values in references as examples, not tuning constants. Pool size,
connection limits, cache size, `GOGC`, `GOMEMLIMIT`, buffer size, and
concurrency limits depend on the workload and environment.

Common valid hypotheses include:

- preallocating a collection when its result size is known
- avoiding retention of a large backing array
- replacing repeated work with a bounded cache
- changing an algorithm whose growth is measured at realistic input sizes
- streaming a large payload instead of buffering it
- reducing contention in a measured critical section
- setting a memory limit with headroom for non-heap memory
- tuning connection reuse from transport metrics and request patterns.

Each can also make performance worse. Verify with the target workload.

## Protect ownership and APIs

- Do not return or retain memory after it goes back to a pool.
- Do not introduce `unsafe` from intuition. Require a measured material gain,
  focused tests, and documented invariants.
- Do not change error identity, ordering, concurrency, or cancellation semantics
  to improve a microbenchmark without user approval.
- Do not add a performance dependency before checking maintenance, license,
  compatibility, and benchmark relevance.
- Do not quote third-party benchmark multipliers as expected project results.

Add a code comment only when a non-obvious optimization needs an invariant or
measurement rationale to prevent an unsafe simplification.

## Review performance claims

Challenge claims that use words such as “zero allocation,” “always faster,” or
“quadratic” without compiler output, a complexity argument, or a benchmark.
Escape behavior is compiler- and context-dependent. Interface conversion,
append, method receivers, and buffer reuse do not have one universal allocation
result.

For HTTP, distinguish idle connection retention from concurrent request limits.
`MaxIdleConnsPerHost` controls idle connections, not the maximum number of
active requests. Use `MaxConnsPerHost` only when a total per-host connection
cap is the intended control.

For JSON arrays, constructing a `json.Decoder` does not by itself make
`Decode(&slice)` item-streaming. To bound item memory, consume the array
delimiters and decode elements individually, or change the protocol.

## Report

Report:

- the original evidence and hypothesis
- the exact baseline and candidate commands
- sample counts and statistical result
- correctness checks
- regressions or trade-offs
- missing tools or measurements
- whether the change was kept or rejected.

Do not claim a performance improvement from code inspection alone.
