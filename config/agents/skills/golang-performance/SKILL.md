---
name: golang-performance
description: |
  Diagnose and optimize Go performance after profiling or benchmarks identify
  a bottleneck. Use for allocation reduction, CPU efficiency, memory layout,
  garbage-collector and runtime tuning, pooling, caching, I/O, hot-path
  optimization, and performance-focused code review. Select targeted changes
  and the measurements needed to validate them. Do not use as a substitute for
  profiling, benchmark design, or correctness testing.
compatibility: |
  Requires a Go toolchain. Statistical benchmark comparison benefits from
  benchstat; other profiling tools are optional and workload-dependent.
---

# Go Performance Optimization

Act as a Go performance engineer.
Measure first, form a specific hypothesis, change one variable,
and measure again.
Follow repository-specific instructions and prefer its existing test,
benchmark, and profiling commands.

## Working Modes

Choose the mode that matches the available evidence:

- **Architecture review** — scan a package or service for structural
  anti-patterns in allocation and memory layout, I/O and concurrency,
  and algorithmic complexity and caching.
- **Hot-path review** — analyze a function or tight loop already identified
  by the caller or a profile.
- **Optimization** — improve a measured bottleneck through the iterative cycle:
  define the metric, establish a baseline, diagnose, change one variable,
  and compare.

All modes can be performed sequentially.
When the execution environment supports safe parallel work,
the three architecture-review concerns may be assessed independently.
Run performance measurements serially on shared hardware
so concurrent workloads do not contaminate results.

## Tooling

- Use repository-defined commands before raw `go` commands.
- Treat `benchstat` as recommended, not mandatory.
  If it is unavailable, report that statistical comparison is limited.
- Use other tools such as `fgprof`, `perf`, `fieldalignment`,
  or `staticcheck` only when they are available and relevant.
- Do not install missing tools or change the system without user authorization.

## Core Philosophy

1. **Profile before optimizing.**
   Use CPU, heap, allocation, block, mutex, goroutine,
   or execution profiles to locate the dominant cost.
2. **Optimize the measured resource.**
   Allocation reduction often helps Go workloads,
   but it cannot fix an I/O-bound or algorithmic bottleneck.
3. **Preserve correctness.**
   Run relevant tests before and after the change,
   and include correctness checks in benchmarks when needed.
4. **Change one variable at a time.**
   This keeps the cause of a result attributable.
5. **Document non-obvious trade-offs.**
   Record the metric, benchmark conditions, and result where future maintainers
   can use them; add a code comment only when the optimization would otherwise
   look incorrect or unnecessary.

## Rule Out External Bottlenecks First

Before optimizing Go code, verify that the bottleneck is in the process.
If most latency comes from a database or remote API,
reducing local allocations will not materially improve it.

Use the evidence available in the environment:

- A wall-clock profiler such as `fgprof` distinguishes on-CPU work
  from off-CPU waiting.
- A goroutine profile shows callers blocked in network or database operations.
- Distributed traces show which upstream span dominates end-to-end latency.

When the bottleneck is external,
optimize that component through query tuning, batching, caching,
connection-pool changes, or request-shaping as the evidence requires.
See [Caching Patterns](references/caching.md) for applicable cache patterns.

## Iterative Optimization Methodology

### The cycle: Define Goals → Benchmark → Diagnose → Improve → Benchmark

1. **Define the metric and target.**
   Choose latency, throughput, allocations, memory, CPU,
   or another workload-relevant metric.
2. **Protect correctness.**
   Identify the relevant tests and make the benchmark representative
   of the production path.
3. **Measure a baseline.**
   Run multiple samples under controlled conditions.
4. **Diagnose.**
   Use the **Diagnose** guidance in the relevant deep-dive section.
5. **Improve.**
   Apply one optimization tied to the profile evidence.
6. **Repeat the same measurement.**
   Keep the workload, machine, toolchain, and command comparable.
7. **Compare.**
   Use `benchstat` when available and account for variance,
   not just the best individual result.
8. **Keep or reject the change.**
   Retain it only when the target metric improves without unacceptable
   correctness, latency, memory, or maintainability regressions.

For example, create a unique benchmark-artifact directory
outside tracked source.
Use its recorded absolute path for `benchmark_dir`
if shell state does not persist between commands.
Capture the baseline first:

```bash
set -o pipefail
benchmark_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
benchmark_dir="$(mktemp -d "/tmp/go-bench-${benchmark_stamp}-XXXXXX")" \
  || exit 1
printf 'benchmark directory: %s\n' "${benchmark_dir}"
go test -run='^$' -bench=BenchmarkMyFunc -benchmem -count=6 ./pkg/... \
  | tee "${benchmark_dir}/baseline.txt"
```

Stop and apply exactly one candidate code change.
In the next block,
replace the placeholder assignment with the exact path printed above.
The directory check prevents an unresolved placeholder
from writing somewhere unintended.
Then repeat the same measurement and compare it with the recorded baseline:

```bash
set -o pipefail
benchmark_dir="/absolute/path/printed-by-the-baseline-step"
if [[ ! -d "${benchmark_dir}" ]]; then
  printf 'benchmark directory does not exist: %s\n' "${benchmark_dir}" >&2
  exit 1
fi
go test -run='^$' -bench=BenchmarkMyFunc -benchmem -count=6 ./pkg/... \
  | tee "${benchmark_dir}/candidate.txt"
benchstat "${benchmark_dir}/baseline.txt" "${benchmark_dir}/candidate.txt"
```

Store measurement artifacts in unique temporary paths
or a project-approved location.
Refer to current library documentation before inventing a custom solution.

When several optimizations target the same bottleneck,
evaluate each from the same baseline and isolate their code changes
using the version-control workflow permitted by the project.
Build variants independently if useful,
but benchmark them serially under comparable conditions.

## Decision Tree: Where Is Time Spent?

<!-- markdownlint-disable MD013 -->
| Bottleneck | Signal (from pprof) | Action |
| --- | --- | --- |
| Too many allocations | `alloc_objects` high in heap profile | [Memory optimization](references/memory.md) |
| CPU-bound hot loop | function dominates CPU profile | [CPU optimization](references/cpu.md) |
| GC pauses / OOM | high GC%, container limits | [Runtime tuning](references/runtime.md) |
| Network / I/O latency | goroutines blocked on I/O | [I/O & networking](references/io-networking.md) |
| Repeated expensive work | same computation/fetch multiple times | [Caching patterns](references/caching.md) |
| Wrong algorithm | O(n²) where O(n) exists | [Algorithmic complexity](references/caching.md#algorithmic-complexity) |
| Lock contention | mutex/block profile hot | Reduce or shard critical sections based on profile evidence |
| Slow queries | DB time dominates traces | Tune queries, indexes, batching, and pool settings in the database layer |
<!-- markdownlint-enable MD013 -->

## Common Mistakes

<!-- markdownlint-disable MD013 -->
| Mistake | Fix |
| --- | --- |
| Optimizing without profiling | Profile first and tie each change to measured evidence |
| Default `http.Client` without Transport | `MaxIdleConnsPerHost` defaults to 2; set to match your concurrency level |
| Logging in hot loops | Log calls can block inlining or allocate even when disabled; benchmark typed `slog.LogAttrs` calls |
| `panic`/`recover` as control flow | panic allocates a stack trace and unwinds the stack; use error returns |
| `unsafe` without benchmark proof | Only justified when profiling shows >10% improvement in a verified hot path |
| No memory limit in containers | Set `GOMEMLIMIT` below the container limit with measured headroom for non-heap memory |
| `reflect.DeepEqual` in a hot path | Benchmark a typed comparison such as `slices.Equal`, `maps.Equal`, or `bytes.Equal` |
<!-- markdownlint-enable MD013 -->

## Deep Dives

- [Memory Optimization](references/memory.md) —
  allocation patterns, backing array leaks, `sync.Pool`, and struct alignment
- [CPU Optimization](references/cpu.md) —
  inlining, cache locality, false sharing, ILP, and reflection avoidance
- [I/O & Networking](references/io-networking.md) —
  HTTP transport configuration, streaming, JSON, cgo, and batch operations
- [Runtime Tuning](references/runtime.md) —
  GOGC, GOMEMLIMIT, GC diagnostics, GOMAXPROCS, and PGO
- [Caching Patterns](references/caching.md) —
  complexity, compiled patterns, `singleflight`, and work avoidance
- [Production Observability](references/observability.md) —
  Prometheus metrics, PromQL, continuous profiling, and alerting rules

## CI Regression Detection

Automate benchmark comparison only for benchmarks that are stable
in the CI environment.
Use dedicated or otherwise controlled runners,
collect multiple samples, compare them statistically,
and derive regression thresholds from observed variance.
