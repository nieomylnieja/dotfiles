---
name: golang
description: >-
  Use whenever reading, writing, reviewing, or modifying Go code, Go modules,
  or Go tooling configuration.
---

# Go

Use idiomatic, version-compatible Go. Inspect the repository before applying
general advice because project conventions and supported Go versions take
precedence over this skill.

Related skills:

- [golang-testing](../golang-testing/SKILL.md) for tests and benchmarks
- [golang-comments](../golang-comments/SKILL.md) for Go doc comments
- [golang-performance](../golang-performance/SKILL.md) for measured optimization

## Determine the Target Go Version

<!-- markdownlint-disable-next-line MD013 -->
!`gomod=$(go env GOMOD); if [ -n "$gomod" ] && [ "$gomod" != "/dev/null" ]; then awk '$1 == "go" { print $2; found=1; exit } END { if (!found) print "unknown" }' "$gomod"; else echo unknown; fi`

Treat the value above as an initial signal, not the complete compatibility
contract.

1. Identify the module that owns the changed package. A workspace can contain
   modules with different `go` directives.
2. Read that module's `go.mod`. The `go` directive declares its minimum Go
   version, controls language semantics, and can select version-dependent
   standard-library behavior. A `toolchain` directive suggests a toolchain; it
   does not raise the module's language version.
3. Check file-specific `//go:build go1.N` constraints. They can raise the
   language version for a file.
4. Check `go.work`, CI, build images, and release policy for older supported
   toolchains or modules.
5. If no target can be established, state that and ask the user before using a
   version-sensitive feature.

When the target is known, state it briefly. Use compatible modern features when
they improve clarity, correctness, or measured performance. Do not use a newer
feature merely because it exists.

Consult [versioned-features.md](./references/versioned-features.md) before
introducing or recommending a feature added after Go 1.17.

## Inspect and Verify

Prefer repository-defined commands in a `Makefile`, `justfile`, CI workflow, or
developer guide. They can include build tags, generated-file checks, nested
modules, and formatting rules that bare Go commands miss.

For code navigation and API questions:

1. Use `gopls` through an available language-server tool for symbols,
   references, diagnostics, and type information.
2. Use `go doc` or official package documentation for API contracts.
3. Read dependency or standard-library source when implementation details are
   relevant.

Do not depend on an integration that is not available. Do not infer API
behavior from source alone when public documentation defines the contract.

Formatting and checks:

- Use the project's formatting target first.
- Otherwise, run `gofmt` on changed Go files. Run `goimports` only when the
  project uses it or import organization needs it.
- Run the project's tests and checks after changes.
- If no project command exists, use relevant commands such as `go test ./...`,
  `go vet ./...`, and the configured linter.
- Treat `golangci-lint` as a linter unless its formatter command is explicitly
  configured. A lint run does not replace formatting.
- Run `govulncheck ./...` after dependency changes or source changes that can
  alter vulnerable-call reachability when the tool is available.

Report the exact command and error when a required check cannot run.

## Dependencies and Modules

Use the standard library when it meets the requirements. Before adding a
dependency, check [libraries.md](./references/libraries.md), repository policy,
maintenance status, licenses, supported Go versions, and the dependency's
transitive cost.

Preserve the repository's `go.mod` organization. Go does not require a fixed
number of `require` blocks. After adding, removing, or updating dependencies,
run the repository's module-maintenance target or `go mod tidy`, then review the
`go.mod` and `go.sum` diff for unintended changes.

## Structure and Style

- Follow the package's established file and declaration organization. Group
  related declarations so the public API and control flow are easy to find.
- Prefer guard clauses when they reduce nesting. Do not replace a clear
  `if`/`else` chain with `switch` mechanically.
- Extract a branch only when doing so gives it a useful abstraction or makes
  the caller materially easier to read.
- Let `gofmt` decide ordinary layout. For a long declaration, a vertically
  formatted parameter list is usually clearer than arbitrary wrapping.
- For fluent call chains that span lines, use the Go-valid style with the dot
  at the end of the preceding line.
- Use `net.JoinHostPort` for host-and-port addresses. It handles IPv6 literals
  correctly. Convert an integer port with `strconv.Itoa`.

Keep comments focused on contracts, invariants, side effects, constraints, and
non-obvious rationale. Do not ban inline comments: use them sparingly when code
cannot express the reason. Follow the comment skills linked above.

## Interfaces

Create an interface only when a consumer needs behavioral substitution or when
an API represents a stable shared contract. A concrete parameter is simpler
when no abstraction is needed.

Prefer narrow interfaces defined near the consumer. Return a concrete type by
default so callers retain its full API. A producer-side interface can be valid
for multiple hidden implementations, a deliberately shared contract, or an
implementation type that should remain hidden.

Use [interface-design.md](./references/interface-design.md) for the full
decision guide.

## Errors and Panics

After checking that `err` is non-nil, add useful operation or resource context.
Preserve the error chain when callers should be able to inspect the underlying
error:

```go
return fmt.Errorf("open config %q: %w", path, err)
```

Use `errors.Is` and `errors.As` (or `errors.AsType` on Go 1.26+) instead of
matching error text. Handle an error close to the operation unless a deliberate
aggregation or cleanup pattern requires otherwise. Never discard an error
silently.

Wrapping with `%w` exposes the underlying error through `errors.Is` and
`errors.As`, which can become part of a public API contract. Use `%v` or a
package-defined error when the abstraction should hide that error identity.

Do not add `github.com/pkg/errors` or `golang.org/x/xerrors` solely for wrapping
in modern Go; `%w`, `errors.Is`, `errors.As`, and `errors.Join` cover the
standard cases. Preserve existing third-party use when compatibility or
required stack-capture behavior justifies it.

Return errors for expected failures and failures callers can handle. Panic is
appropriate only for a documented programmer-contract violation or an internal
invariant that makes continued execution invalid. A library is not categorically
forbidden from panicking, but runtime input and environmental failures should
normally be errors.

## API and Naming

- Design useful zero values when doing so does not hide required setup.
- Use named results when they clarify otherwise ambiguous values or support a
  necessary deferred update. Avoid naked returns in long functions.
- Use directional channel types at API boundaries when only send or receive is
  permitted.
- Pass `context.Context` as the first parameter to operations that may block or
  be canceled. Do not store it in a struct by default; a rare exception needs a
  documented lifetime reason.
- Avoid catch-all packages such as `utils` or `common`. Name a package for the
  cohesive capability it provides.
- Consult [naming-patterns.md](./references/naming-patterns.md) instead of
  applying naming slogans mechanically.

## Concurrency

Use `errgroup.WithContext` when sibling tasks should stop after one fails and
the tasks can observe cancellation. It reports the first non-nil error, and
`Wait` still waits for every task to return. Bound concurrency with `SetLimit`
or a worker pool when task count or cost is not tightly bounded. Use
`sync.WaitGroup` when tasks do not return errors or manage errors independently.
On Go 1.25+, `WaitGroup.Go` can remove bookkeeping only when its function will
not panic; its contract says the function must not panic.

Loop variables declared by the loop have per-iteration scope in files compiled
with Go 1.22 or later language semantics. The owning module's `go` directive
normally selects those semantics, but a file-level `//go:build go1.N`
constraint can raise them for that file. Preexisting variables assigned by the
loop remain shared. Under older semantics, capture a copy before a closure
retains a declared loop variable.

Default to `sync.Mutex`. Consider `sync.RWMutex` only after a representative
benchmark or profile shows read-lock concurrency helps. Read/write ratios alone
do not prove it is faster. Never try to upgrade an `RLock` to `Lock`; release
the read lock, acquire the write lock, and recheck the protected state.

Place a mutex immediately before the fields it protects when that layout makes
the invariant clear.

## Collections and Types

Choose slice construction from the output contract:

- Use `make([]T, n)` and indexed assignment for a fixed one-to-one result when
  every element is written.
- Use `make([]T, 0, n)` and `append` for filtered, conditional, or variable-size
  output.

Both forms can perform one backing-array allocation. The important difference
is length semantics, not a universal performance rule.

Name a complex map type when that improves signatures:

```go
type ProjectAlertStatuses map[ProjectName]map[AlertID]AlertStatus
```

Use defined key and value types when the compiler should distinguish concepts:

```go
type ProjectName string
type AlertID string
type AlertStatus string
```

A type alias such as `type ProjectName = string` adds a name in source but no
type distinction. Do not claim that aliases enforce key semantics. Named types
also do not replace documentation for allowed values, ownership, mutability, or
concurrency.

## Version-Aware Modernization

[versioned-features.md](./references/versioned-features.md) records the first Go
release for selected language and standard-library features, plus important
qualifications. Check it before replacing an older pattern. A newer construct
is not automatically better in every context; preserve behavior, readability,
and the module's target version.
