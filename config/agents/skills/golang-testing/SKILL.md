---
name: golang-testing
description: >-
  Use when writing or reviewing Go tests, benchmarks, fuzz tests, examples,
  test helpers, or Go test infrastructure.
---

# Go testing

Use the owning module's Go version and the repository's test conventions.
Load [golang](../golang/SKILL.md) for Go code and
[bats-testing-patterns](../bats-testing-patterns/SKILL.md) when the behavior
under test is a command-line workflow.

## Establish the test contract

Before editing:

1. Identify the package and owning `go.mod`.
2. Read its `go` and optional `toolchain` directives.
3. Inspect nearby tests, build tags, shared helpers, and dependencies.
4. Find project test targets and CI commands.
5. Identify the smallest observable behavior that detects the regression.

Do not infer the version from the most common `go.mod` in a multi-module
repository. Do not add Testify, GoMock, or another test dependency unless the
module already uses it or the user accepts the dependency.

## Test design

- Test behavior and contracts, not private implementation steps.
- Keep a focused regression test for each changed failure mode.
- Use a table when cases share setup and assertions. Use separate tests when a
  table would need many optional fields or branches.
- Give each table case or subtest a short, descriptive name.
- Use maps only when randomized case order is useful and order is irrelevant.
  Use slices when deterministic order improves diagnosis.
- Put tests before file-local helpers when that matches the repository. Keep
  related setup close enough that the test remains readable.
- Call `t.Helper()` in helpers that report failures.
- Use `testdata/` for files that belong to the package's test corpus.
- Check every setup error before using its result.

Example with the standard library:

```go
func TestParsePort(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    int
		wantErr error
	}{
		{name: "valid", input: "8080", want: 8080},
		{name: "negative", input: "-1", wantErr: ErrPortRange},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := ParsePort(tt.input)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("ParsePort() error = %v, want %v", err, tt.wantErr)
			}
			if err == nil && got != tt.want {
				t.Errorf("ParsePort() = %d, want %d", got, tt.want)
			}
		})
	}
}
```

Prefer `errors.Is` or `errors.As` for errors with stable identity or type.
Assert exact text only when text is part of the public contract. Use a narrow
substring assertion only when variable context prevents an exact comparison.

When the project uses Testify, use `require` for prerequisites and `assert`
for independent checks. Do not convert standard-library assertions merely for
uniformity.

## Parallel tests

Use `t.Parallel()` only when concurrent execution is safe and useful. A parent
test does not need `t.Parallel()` merely because its subtests use it.

Do not parallelize tests that:

- call `t.Setenv` or `t.Chdir`;
- change the process working directory, environment, flags, locale, or global
  logger;
- replace package globals or process-wide hooks;
- share mutable fixtures, ports, databases, clocks, or mocks;
- depend on execution order or exact timing.

Check the target Go version before adding a loop-variable capture. Loop
variables declared by a `for` loop have per-iteration scope under Go 1.22
language semantics. Variables assigned outside the loop can still be shared.

## Time, context, and cleanup

- Use `t.Cleanup` to restore state owned by a test.
- Use `t.TempDir` for per-test files.
- Use `t.Context()` on Go 1.24+ when the operation should stop as the test
  completes. Keep an explicit derived context when the test must cancel earlier
  or assert cancellation behavior.
- Use `testing/synctest` only on a supported Go version and only for code whose
  concurrency fits a synctest bubble. Do not use it to hide a race.
- Avoid sleeps as synchronization. Prefer events, channels, hooks, or eventual
  assertions with a bounded deadline.
- Run race-sensitive tests with the project's race target or `go test -race`.

`t.Chdir`, `t.Setenv`, and process-global test helpers cannot be combined
with parallel tests. Cryptographic helpers that replace global randomness have
the same process-wide restriction.

## Benchmarks

Benchmark the measured hot path with representative inputs. Keep correctness
checks outside the timed loop when possible and report allocations when they
matter.

Use `b.Loop()` on Go 1.24+ for ordinary benchmark loops. Keep the classic
`b.N` form when compatibility or deliberate timer control requires it.

```go
func BenchmarkEncode(b *testing.B) {
	input := representativeInput()
	b.ReportAllocs()

	for b.Loop() {
		result = Encode(input)
	}
}
```

Do not claim an improvement from one run. Use multiple samples under comparable
conditions and `benchstat` when available. Load
[golang-performance](../golang-performance/SKILL.md) for optimization work.

## Fuzz tests and examples

- Seed fuzz tests with valid, boundary, and previously failing inputs.
- Keep fuzz invariants deterministic and free of external services.
- Preserve failing corpus entries in `testdata/fuzz/<FuzzName>/` when useful.
- Give examples valid names so `go test` and `go doc` associate them with
  the intended symbol.
- Check errors in examples unless the example specifically demonstrates ignored
  output and failure is impossible by construction.

## Verify

Run the repository-defined command with required build tags and environment.
Otherwise run the narrow package first, then the owning module when warranted:

```sh
go test ./path/to/package
go test ./...
```

For a regression test, prove that it fails without the fix when this can be done
without losing user changes. Report skipped race, integration, fuzz-duration,
or cross-platform checks explicitly.
