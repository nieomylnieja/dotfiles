# Versioned Go Features

This catalog records the first Go release for selected language and
standard-library features. Use it as a compatibility check, not as a mandate to
rewrite working code.

## Contents

- [Compatibility Rules](#compatibility-rules)
- [Go 1.18](#go-118)
- [Go 1.19](#go-119)
- [Go 1.20](#go-120)
- [Go 1.21](#go-121)
- [Go 1.22](#go-122)
- [Go 1.23](#go-123)
- [Go 1.24](#go-124)
- [Go 1.25](#go-125)
- [Go 1.26](#go-126)
- [Modernization Decisions](#modernization-decisions)
- [Official Sources](#official-sources)

## Compatibility Rules

- The heading identifies the first release that provides the listed feature.
- The module's `go` directive controls which language features its packages may
  use. Some standard-library behavior changes also inspect the main module's
  `go` directive.
- The `toolchain` directive can select a newer toolchain but does not change the
  module's language version.
- Check CI, published support policy, nested modules, and consumers before
  raising a `go` directive.
- Preserve semantics. A shorter API is not automatically clearer or correct for
  a particular use.
- Experimental APIs and `GOEXPERIMENT` features are not stable defaults.

## Go 1.18

### Language and aliases

- Type parameters and constraints were added. Use generics when one algorithm
  genuinely applies across types and the result is clearer than duplication or
  an interface.
- `any` is an alias for `interface{}`. Prefer `any` in ordinary new code, but do
  not churn stable APIs solely to rename the identical type.
- Let the compiler infer function type arguments when arguments provide enough
  information. Explicit type arguments remain valid and are needed when a type
  cannot be inferred or inference would select the wrong type.

### Library

- `strings.Cut` and `bytes.Cut` split around the first separator and report
  whether it was present. They often replace an index check followed by manual
  slicing.
- `sync.Mutex.TryLock` and `sync.RWMutex.TryLock` were added. Failed lock
  acquisition is rarely a reason to redesign clear blocking synchronization;
  use these only when the non-blocking contract is real.

## Go 1.19

- `fmt.Append`, `fmt.Appendf`, and `fmt.Appendln` append formatted output to a
  byte slice. They can avoid the intermediate string from `fmt.Sprintf` when a
  byte buffer is already being built.
- Typed atomics such as `atomic.Bool`, `atomic.Int64`, and
  `atomic.Pointer[T]` reduce misuse of the older free functions. Atomic fields
  still require a documented synchronization protocol.

## Go 1.20

- `errors.Join` combines non-nil errors into one error whose `Unwrap` method
  returns multiple children. Use it when callers should be able to inspect all
  failures with `errors.Is` or `errors.As`.
- `strings.CutPrefix`, `strings.CutSuffix`, and their `bytes` equivalents remove
  a prefix or suffix and report whether it matched.
- `context.WithCancelCause` and `context.Cause` preserve a meaningful
  cancellation cause. Consumers still need to obey the context lifetime and
  call the returned cancel function.
- `httputil.ReverseProxy.Rewrite` was added. Prefer it to `Director` for new
  reverse proxies; `Director` was formally deprecated in Go 1.26 because of its
  hop-by-hop header behavior.

## Go 1.21

### Built-ins and generic helpers

- Built-ins `min`, `max`, and `clear` were added. `clear` deletes all map
  entries or zeros all slice elements; it does not change a slice's length.
- Packages `slices`, `maps`, and `cmp` provide common generic operations.
  `slices.Sort` works for ordered element types. Use `slices.SortFunc` when
  ordering needs a comparator; it is not interchangeable with every
  `sort.Slice` call.

### Logging, context, and one-time functions

- `log/slog` provides structured logging in the standard library.
- `context.AfterFunc` runs a function after cancellation. The returned stop
  function reports whether it prevented the callback from starting; stopping
  it does not wait for a callback that already started.
- `context.WithDeadlineCause` and `context.WithTimeoutCause` attach a cause to
  deadline expiry.
- `sync.OnceFunc`, `sync.OnceValue`, and `sync.OnceValues` return concurrent-safe
  wrappers that run the supplied function once. `OnceValue` caches one result;
  `OnceValues` caches two. If the supplied function panics, every call to the
  wrapper panics with the same value.

These one-time wrappers replace manual `sync.Once` state only when their cached
return shape and panic replay are the desired contract. This differs from
`Once.Do`: if its function panics, that call propagates the panic, but later
`Do` calls return without invoking the function or replaying the panic.

## Go 1.22

### Language

- `for range` can range over an integer for simple zero-based, unit-step loops.
  A three-clause loop remains appropriate for other bounds, steps, or mutation.
- Variables declared by a `for` loop have per-iteration scope in files compiled
  with Go 1.22 or later language semantics. The module's `go` directive
  normally selects those semantics; a file-level `//go:build go1.N` constraint
  can raise them for that file. Preexisting variables assigned with `=` remain
  reused. A newer toolchain alone does not change the semantics.

### Library

- `cmp.Or` returns the first non-zero argument. Function arguments are evaluated
  eagerly, so it is not equivalent to a lazy cascade when candidates have side
  effects or material computation cost.
- `http.ServeMux` accepts method-aware patterns and wildcards. Review precedence
  and conflicts when migrating an existing router. Go 1.22 provides the
  `httpmuxgo121` `GODEBUG` setting as a temporary compatibility switch.
- `reflect.TypeFor[T]` obtains the `reflect.Type` for a type parameter without a
  pointer-and-`Elem` workaround.
- `math/rand/v2` provides revised pseudo-random APIs. It is not a source of
  cryptographic randomness.

The package-level `math/rand.Seed` function did not become a no-op in this
release; that default changed in Go 1.24.

## Go 1.23

### Iterators

- Range-over-function iterator syntax and package `iter` were added.
- `maps.Keys` and `maps.Values` return iterators. Use `slices.Collect` or
  `slices.Sorted` only when a materialized slice is required.
- `slices.Collect` materializes an iterator. Avoid collecting only to iterate
  once. It returns a nil slice for an empty sequence, which differs from a
  manually allocated non-nil empty slice when nilness is observable.
- `reflect.Value.Seq` and `reflect.Value.Seq2` expose supported reflected values
  as iterators. Check `reflect.Type.CanSeq` or `CanSeq2` when the kind is not
  statically known.
- Package `unique` interns comparable values and returns comparable handles.
  Use it only when interning semantics and memory behavior suit the workload.

### Timers and tickers

For a main module that declares Go 1.23 or later, timer and ticker channels use
the new synchronous semantics, and unreferenced timers and tickers can be
garbage-collected even if their `Stop` methods were not called. The
`asynctimerchan` `GODEBUG` setting can select the old behavior temporarily.

This does not make lifecycle management obsolete. Call `Stop` when future
ticks or timer work should cease. The change only means an unreachable timer or
ticker no longer needs `Stop` solely to become garbage-collection eligible.

## Go 1.24

### JSON `omitzero`

The `encoding/json` `omitzero` tag option omits a field when its value is zero
according to an `IsZero() bool` method or the Go zero value. It and `omitempty`
express different wire contracts:

- `omitempty` omits false, numeric zero, nil pointers or interfaces, and values
  with length zero, including non-nil empty slices and maps.
- `omitzero` can omit zero struct values such as `time.Time{}`. A non-nil empty
  slice or map is empty but is not its Go zero value.
- Both options may be combined when either condition should omit the field.

Choose the tag from the required JSON representation. Do not replace
`omitempty` globally or claim it is defective.

### Other additions and changes

- `strings.SplitSeq`, `strings.FieldsSeq`, and their `bytes` equivalents avoid
  constructing a slice when results are consumed once by iteration.
- A `tool` directive in `go.mod` records executable tool dependencies. Follow
  the repository's existing tool-management policy before migrating a
  `tools.go` setup.
- `os.OpenRoot` returns an `os.Root` that confines filesystem operations to a
  directory. Handle errors and close the root.
- `cipher.NewGCMWithRandomNonce` manages nonces for AES-GCM and prefixes the
  generated nonce to the ciphertext. Check its documented ciphertext and
  nonce-size contract before changing a protocol. A key must encrypt no more
  than 2^32 messages because random nonces can collide.
- Package-level `math/rand.Seed` is a no-op by default. For reproducible local
  pseudo-random sequences, construct a `rand.Rand` with a seeded source. The
  temporary `randseednop=0` `GODEBUG` setting restores the old package-level
  behavior.

## Go 1.25

### Concurrency and runtime

- `sync.WaitGroup.Go` starts a task and manages the counter. Its documented
  contract says the function must not panic. Do not require it when panic
  behavior, explicit recovery, externally started work, or another task
  abstraction calls for manual `Add` and `Done` management.
- On Linux, the runtime's default `GOMAXPROCS` considers cgroup CPU limits and
  can update as limits change. Explicit `GOMAXPROCS` settings and relevant
  `GODEBUG` controls can disable the automatic behavior. Do not assume this
  behavior on every operating system or deployment.

### Library and experiments

- `net/http.CrossOriginProtection` provides browser-origin checks for handlers.
  Confirm that its threat model and trusted origins match the application; it
  is not a universal CSRF design for every protocol.
- `runtime/trace.FlightRecorder` retains a rolling execution trace for later
  snapshots.
- `reflect.TypeAssert[T]` avoids the `Value.Interface().(T)` form and can avoid
  its allocation.
- `encoding/json/v2` remains experimental behind `GOEXPERIMENT=jsonv2` in Go
  1.25. Do not adopt it as a stable default without explicit project approval
  and compatibility testing.

## Go 1.26

### Language and errors

- `new(expr)` creates a pointer to a new variable initialized with the
  expression. It can replace trivial pointer helper functions when the target
  module is Go 1.26 or later.
- Generic types may refer to themselves in their type parameter lists, enabling
  self-referential constraints.
- `errors.AsType[E]` is the type-safe generic counterpart to `errors.As`. Use it
  for a statically known error type when the target is Go 1.26 or later.
  Existing `errors.As` code remains valid and supports broader dynamic target
  forms.

### Tools and library

- `go fix` was rebuilt around analysis-based modernizers. Inspect
  `go tool fix help` for the installed toolchain's analyzers instead of keeping
  an assumed exhaustive list. Review its diff and run the full test suite.
- `log/slog.NewMultiHandler` sends records to multiple handlers.
- `bytes.Buffer.Peek` returns up to the next `n` bytes without advancing the
  buffer. The returned slice aliases buffer storage and is valid only until the
  next read or write method call.
- Reflection added iterator methods including `reflect.Type.Fields`,
  `reflect.Type.Methods`, `reflect.Value.Fields`, and
  `reflect.Value.Methods`; use them when iterator semantics improve the code.
- `httputil.ReverseProxy.Director` is deprecated in favor of `Rewrite`.

### Cryptographic random parameters

Go 1.26 ignores reader parameters for specific operations in `crypto/dsa`,
`crypto/ecdh`, `crypto/ecdsa`, `crypto/rand.Prime`, and selected `crypto/rsa`
operations, using secure internal randomness instead. For `crypto/ed25519`, the
change applies when `GenerateKey` receives a nil reader. It is false that every
crypto function ignores every random-reader parameter.

Use the operation's Go 1.26 documentation. For deterministic cryptographic
tests, use `testing/cryptotest.SetGlobalRandom` where supported. The temporary
`cryptocustomrand=1` `GODEBUG` setting restores old behavior for affected APIs.

## Modernization Decisions

Apply these replacements only when their stated condition holds:

<!-- markdownlint-disable MD013 -->
| Older form | Candidate replacement | Condition |
| --- | --- | --- |
| `interface{}` | `any` | Target is Go 1.18+ and churn is justified |
| Manual ordered sort | `slices.Sort` | Target is Go 1.21+ and elements are ordered |
| Custom comparator sort | `slices.SortFunc` | Target is Go 1.21+ and comparator semantics match |
| Closure loop-variable copy | Remove the copy | Affected file uses Go 1.22+ language semantics |
| Simple `for i := 0; i < n; i++` | `for i := range n` | Target is Go 1.22+ and loop is zero-based/unit-step |
| Manual map-key slice | `slices.Collect(maps.Keys(m))` | Target is Go 1.23+; a slice is required and nilness may change |
| JSON `omitempty` | `omitzero` or both | Target is Go 1.24+ and wire semantics require zero testing |
| WaitGroup bookkeeping | `WaitGroup.Go` | Target is Go 1.25+ and task must not panic |
| Pointer helper | `new(expr)` | Target is Go 1.26+ and helper has no other semantics |
| `errors.As` target variable | `errors.AsType` | Target is Go 1.26+ and generic form is clearer |
| `ReverseProxy.Director` | `ReverseProxy.Rewrite` | Target is Go 1.20+; preferred when resolving the Go 1.26 deprecation |
| Host/port formatting | `net.JoinHostPort` | Address is a network host and port |
<!-- markdownlint-enable MD013 -->

## Official Sources

- [Go 1.18 release notes](https://go.dev/doc/go1.18)
- [Go 1.19 release notes](https://go.dev/doc/go1.19)
- [Go 1.20 release notes](https://go.dev/doc/go1.20)
- [Go 1.21 release notes](https://go.dev/doc/go1.21)
- [Go 1.22 release notes](https://go.dev/doc/go1.22)
- [Go 1.23 release notes](https://go.dev/doc/go1.23)
- [Go 1.23 timer channel changes](https://go.dev/wiki/Go123Timer)
- [Go 1.24 release notes](https://go.dev/doc/go1.24)
- [Go 1.25 release notes](https://go.dev/doc/go1.25)
- [Go 1.26 release notes](https://go.dev/doc/go1.26)
