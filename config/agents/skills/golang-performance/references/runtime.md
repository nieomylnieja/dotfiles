# Runtime Tuning

<!-- markdownlint-disable MD013 -->

Runtime settings control garbage collection frequency, memory limits, CPU scheduling, and compiler optimizations. Tune them after profiling — the defaults are well-chosen for most workloads.

## Garbage Collector Tuning

**Diagnose:** Compare GC CPU, allocation rate, live heap, assists, and pauses
against the service objective. Use `gctrace`, runtime metrics, profiles, and
traces. No single GC frequency or CPU percentage is a universal failure
threshold.

### GOGC (default: 100)

Controls the target percentage of new heap data relative to the live heap after
the previous collection. Higher values usually trade more memory for less GC
CPU. Measure latency and throughput instead of assigning values by service type:

```bash
GOGC=50  ./myapp  # lower heap-growth target
GOGC=200 ./myapp  # higher heap-growth target
GOGC=off ./myapp  # disable GC entirely (testing only!)
```

### GOMEMLIMIT (Go 1.19+)

`GOMEMLIMIT` sets a soft target for memory managed by the Go runtime. It does
not cap total process RSS. The target excludes the binary, C allocations,
memory mapped through `syscall.Mmap`, and kernel memory held for the process.
Choose it from measurements of both managed and excluded memory under load.
Reserve process or container capacity for the excluded memory.

The runtime changes GC frequency and memory release behavior as managed memory
approaches the target. A target below the working set can cause near-continuous
GC without protecting the process from excluded memory.

### Programmatic control

```go
import "runtime/debug"

func configureRuntime(gcPercent int, memoryLimitBytes int64) {
    debug.SetGCPercent(gcPercent)
    debug.SetMemoryLimit(memoryLimitBytes)
}
```

Use programmatic control when configuration or a measured workload supplies
the values. Verify total process memory after each change.

## GC Profiling and Diagnostics

### GODEBUG=gctrace=1

Prints a line per GC cycle to stderr:

```bash
GODEBUG=gctrace=1 ./myapp 2>&1 | head -20
```

Sample output:

```text
gc 5 @1.234s 2%: 0.012+12+0.9 ms clock, 0.25+8.9/20+18 ms cpu, 45->92->50 MB, 200 MB goal, 8 P
```

Key fields:

- `gc 5` — 5th GC cycle
- `@1.234s` — time since program start
- `2%` — total CPU time spent in GC
- `45->92->50 MB` — heap at collection start → heap at collection end →
  live heap
- `200 MB goal` — target heap size (based on GOGC and GOMEMLIMIT)
- `8 P` — number of processors

Interpret GC frequency, pauses, and CPU together with allocation profiles and
the latency objective. Each signal has several possible causes.

### runtime.ReadMemStats

Programmatic monitoring for dashboards and alerting:

```go
var m runtime.MemStats
runtime.ReadMemStats(&m)

fmt.Printf("Alloc: %d MB\n", m.Alloc/1024/1024)       // currently allocated
fmt.Printf("TotalAlloc: %d MB\n", m.TotalAlloc/1024/1024) // cumulative
fmt.Printf("Sys: %d MB\n", m.Sys/1024/1024)            // requested from OS
fmt.Printf("NumGC: %d\n", m.NumGC)                      // completed collections
fmt.Printf("LastPause: %d ms\n", m.PauseNs[(m.NumGC+255)%256]/1_000_000)
```

### GC pacing

The GC pacer predicts when to start the next collection based on:

1. **Live heap size** after the last collection
2. **GOGC percentage** — how much growth to allow
3. **GOMEMLIMIT** — soft ceiling (if set)
4. **Current allocation rate** — how fast the heap is growing

The pacer starts collection early enough to finish before hitting the target. Fast allocation rates cause earlier starts.

## Allocation Rate Reduction

**Diagnose:**

1. Use an allocation profile to rank allocation sites.
2. Use `GODEBUG=gctrace=1` to compare GC frequency before and after a change.
3. Track `rate(go_memstats_alloc_bytes_total[5m])` to detect production
   regressions.

If allocation rate drives GC cost, reduce hot allocations before runtime
tuning:

- **Check escape behavior** — values and pointers can both escape. Use compiler
  diagnostics and profiles instead of type-shape assumptions
- **Pool temporary objects** only for a measured allocation hotspot. See
  [memory.md](./memory.md)
- **Preallocate slices and maps** with measured size hints. See
  [Memory Optimization](./memory.md#allocation-patterns)
- **Assess interface-heavy hot paths** with profiles and compiler output.
  Compare a typed or generic alternative only when evidence locates the cost

## GOMAXPROCS in Containers

**Diagnose:**

1. Use CPU profiles to measure `runtime.schedule` and
   `runtime.findRunnable`.
2. Use `go tool trace` to inspect work distribution across processors.
3. Use `GODEBUG=schedtrace=1000` to find run-queue imbalance or idle
   processors.
4. Compare `runtime.GOMAXPROCS(0)` with the effective container CPU limit.
5. Track `rate(process_cpu_seconds_total[5m])` to identify CPU saturation.

Go 1.25+ can select the default `GOMAXPROCS` from:

- Logical CPUs on the machine
- Process CPU affinity mask
- Linux cgroup CPU quota

The runtime reads `cpu.max` for cgroup v2. For cgroup v1, it reads
`cpu.cfs_quota_us` and `cpu.cfs_period_us`. The main module's Go language
version and `GODEBUG=containermaxprocs` control whether container-aware
selection is enabled by default. Language versions 1.24 and earlier retain the
older default unless configuration enables the feature.

For a runtime without container-aware selection, assess
`go.uber.org/automaxprocs` against the deployment environment:

```go
// Pre-Go 1.25: explicit container-aware detection
import _ "go.uber.org/automaxprocs"

func main() {
    // The library applies its detected process limit
    startServer()
}
```

The runtime can periodically update its default after quota or affinity changes.
Setting the `GOMAXPROCS` environment variable or calling
`runtime.GOMAXPROCS` disables these updates. A `GODEBUG` setting can also
disable them:

```bash
GOMAXPROCS=2 ./myapp                # fixed override; no automatic updates
GODEBUG=updatemaxprocs=0 ./myapp    # keep the initial default; no updates
```

## Profile-Guided Optimization (PGO)

**Diagnose:** Collect a representative production CPU profile, build with and
without that profile, then compare application benchmarks and binary behavior.

Go 1.21+ supports profile-guided optimization. Results depend on profile
representativeness and the program. Do not promise a fixed improvement.

**Evaluation contract:**

1. Use timestamped `mktemp` calls to create a profile file and private build
   directory outside the repository. Record the exact resolved paths.
2. In each later tool call, pass those resolved paths as literal arguments.
   Do not depend on a shell variable from an earlier call.
3. Collect the profile with the repository command or an HTTP client that
   fails on HTTP errors. Write only to the recorded profile path.
4. Check that the repository-supported pprof frontend is available. Use it to
   parse the recorded profile and inspect the reported functions. Stop on a
   missing frontend, parse failure, or wrong workload.
5. Build outputs outside the repository. Pass the recorded profile path through
   an explicit `-pgo` flag and the recorded candidate path through `-o`. Use
   `-pgo=off` for a comparable baseline when the evaluation needs one.
6. After the evaluation, remove only the recorded profile and build directory.
   Resolve and verify each target before removal.

Do not copy an evaluation profile over `default.pgo`. If publishing the profile
requires creating or replacing `default.pgo`, inspect the current file and get
explicit user authority first.

**What the compiler optimizes:**

- **Inlining** — hot function calls are inlined more aggressively
- **Devirtualization** — interface method calls with high probability of targeting specific types become direct calls

**PGO can help:** code with many interface calls, hot inlining opportunities,
or deep call stacks.

**PGO can help less:** optimized code and memory-bound workloads.

Rebuild profiles after significant code changes — stale profiles can mislead the compiler.

## Logging Overhead in Hot Paths

**Diagnose:**

1. Use a CPU profile to find hot logging and formatting calls.
2. Use `go build -gcflags="-m"` to check whether log arguments escape.
3. Compare enabled and disabled logging with `go test -bench -benchmem`.

Eager log formatting uses memory and CPU before the logger applies its level
filter:

```go
// Bad — fmt.Sprintf runs BEFORE the logger checks the level
logger.Debug(fmt.Sprintf("processing item %d with data %v", item.ID, item.Data))

// Good — slog defers formatting until level check passes (Go 1.21+)
slog.Debug("processing item", slog.Int("id", item.ID), slog.Any("data", item.Data))

// Candidate for a measured hot path
slog.LogAttrs(ctx, slog.LevelDebug, "processing item",
    slog.Int("id", item.ID))
```

In hot paths, even `slog.Any` can allocate. Prefer typed attributes: `slog.Int`, `slog.String`, `slog.Bool`.

## Panic/Recover Cost

**Diagnose:** If `runtime.gopanic` or `runtime.gorecover` is hot, compare the
current control flow with an error-return design under representative failures.

`panic` unwinds the stack and runs deferred functions. Use ordinary errors for
expected failures:

```go
func parseInt(s string) (int, error) {
    value, err := strconv.Atoi(s)
    if err != nil {
        return 0, fmt.Errorf("parse integer %q: %w", s, err)
    }
    return value, nil
}
```

Panic can represent a programmer-contract violation or an unrecoverable
internal invariant. Recover only at a boundary that explicitly owns a panic
contract, such as isolation for a plugin or callback. Do not recover blindly.
