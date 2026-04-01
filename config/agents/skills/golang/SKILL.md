---
name: golang
description: Use this skill when you're working with golang code.
---

# Go

Modern Go best practices, idioms, and version-aware feature usage.
Always detect the project's Go version before writing code.

Related skills:

- [golang-testing](../golang-testing/SKILL.md) for writing tests
- [golang-comments](../golang-comments/SKILL.md) for writing doc comments

**IMPORTANT:** ALWAYS use `LSP` tool rather then grepping/reading module's cache for documentation.

## Go Version Detection

<!-- markdownlint-disable-next-line MD013 -->
!`grep -rh "^go " --include="go.mod" . 2>/dev/null | cut -d' ' -f2 | sort | uniq -c | sort -nr | head -1 | xargs | cut -d' ' -f2 | grep . || echo unknown`

DO NOT search for go.mod files or try to detect the version yourself.
Use ONLY the version shown above.

**If version detected (not "unknown"):**

- Say: "This project uses Go X.XX —
  I'll use modern Go best practices up to and including this version."
- Do NOT list features, do NOT ask for confirmation

**If version is "unknown":**

- Say: "Could not detect Go version in this repository."
- Use AskUserQuestion: "Which Go version should I target?"
  → [1.22] / [1.23] / [1.24] / [1.25] / [1.26]

**When writing Go code**, use ALL features from this document up to the target version:

- Prefer modern built-ins and packages over legacy patterns
- Never use features from newer Go versions than the target
- Never use outdated patterns when a modern alternative exists for the target version

---

## Tooling

Always prefer project-defined checks over bare tool invocations.
Look for a `Makefile`, `justfile`, or similar — run `make lint`, `make check`,
or equivalent targets if they exist.
If no project targets are defined, fall back to the tools below directly.

**Linting — `golangci-lint`:**
The standard meta-linter.
Run before committing and after making changes.

```sh
golangci-lint run ./...
```

Formatting is handled by golangci-lint too (via `gofmt`/`goimports` linters) —
do not run `gofmt` separately unless the project explicitly requires it.

**Vulnerability scanning — `govulncheck`:**
Run after adding or updating dependencies.

```sh
govulncheck ./...
```

**Language server — `gopls`:**
Use the LSP tool to query `gopls` for diagnostics, hover info,
type information, and package documentation.
Prefer this over reading source manually —
it is more accurate, especially for complex generic or interface types.
For package API questions, use `gopls` hover on a symbol before reaching
for any external documentation source.

**Package documentation fallback — Context7 (last resort):**
If `gopls` cannot answer the question
(e.g. the package is not yet imported or the symbol is unknown),
use `mcp__Context7__resolve-library-id` and `mcp__Context7__query-docs`
to look up current documentation.
This avoids hallucinated APIs and catches deprecated signatures.

---

## Preferred Libraries

When adding a dependency,
check [references/libraries.md](./references/libraries.md)
for the project's preferred library picks before reaching for an arbitrary package.
Use the standard library if it already covers the need.

---

## Module Management

`go.mod` must always have exactly two `require` blocks:
one for direct dependencies and one for indirect dependencies.

```text
require (
    github.com/urfave/cli/v2 v2.27.0
    golang.org/x/sync v0.7.0
)

require (
    github.com/cpuguy83/go-md2man/v2 v2.0.3 // indirect
    golang.org/x/text v0.14.0 // indirect
)
```

After adding, removing, or updating dependencies, run:

```sh
go mod tidy
```

`go mod tidy` does not enforce this structure — maintain it manually.
If the file ends up with a single merged block or more than two blocks,
adjusted it by hand.

---

## File Layout

Order declarations top-to-bottom by importance — readers should see the
public API and key logic first, not scroll past helpers to find it.

1. **Package doc comment** (if any)
2. **Constants** (`const` blocks)
3. **Variables** (`var` blocks)
4. **Types** (structs, interfaces, type aliases)
5. **Exported functions and methods** — the public API
6. **Unexported functions and methods** — internal logic
7. **Helper / utility functions** — small, reusable pieces

Within each group, order by logical importance or call order,
not alphabetically.

---

## Code Style Preferences

- Prefer switch statements over if/else chains.
- Use guard clauses (early returns) over nested if/else.
- If and if/else block has a lot of logic in it, separate each branch into a function.
- Use `net.JoinHostPort(host, port)` instead of
  `fmt.Sprintf("%s:%d", host, port)` (IPv6-safe).
- When a function signature exceeds the line length limit,
  put each argument on its own line — do not split arguments
  into two groups to fit the limit.

  ```go
  // WRONG — split in half to fit line length:
  func ProcessItems(ctx context.Context, items []Item,
      opts Options, logger *slog.Logger) error {

  // RIGHT — one argument per line:
  func ProcessItems(
      ctx context.Context,
      items []Item,
      opts Options,
      logger *slog.Logger,
  ) error {
  ```

### Comments

Do not add inline comments to code.
Write self-documenting code — if a comment is needed to explain *what*,
the code should probably be rewritten instead.

Only add inline comments for:

- Non-obvious side effects that cannot be expressed in code
- Rationale or constraints that are not evident from the code itself
  (e.g. a workaround for an upstream bug, a performance trade-off decision)

For functions, types, methods, consts, and vars:
follow the doc comment conventions from the
[golang-comments](../golang-comments/SKILL.md) skill.

---

## Go Idioms

**Accept interfaces, return structs.**
Function parameters should be interfaces (e.g., `io.Reader`),
return types should be concrete structs.

**Wrap errors with context.**
Use `fmt.Errorf("failed X: %w", err)` to add context
while preserving the error chain.
Never discard errors silently.
Do NOT use `github.com/pkg/errors` or `golang.org/x/xerrors` —
both predate Go 1.13's built-in wrapping and are obsolete.
Avoid wrapping with a message like "doing X", explicitly say what failed.

```go
// WRONG — pkg/errors:
return errors.Wrap(err, "open config")
return errors.WithMessage(err, "open config")

// WRONG — x/xerrors (no Wrap; uses Errorf with %w, but still obsolete):
return xerrors.Errorf("open config: %w", err)

// RIGHT — standard library since Go 1.13:
return fmt.Errorf("open config: %w", err)
```

The `%w` verb makes the error unwrappable via `errors.Is` and `errors.As`.

**Handle errors immediately.**
Check `err != nil` right after the call —
don't defer error checks or accumulate them.

**Zero values should be useful.**
Design structs so the zero value is a valid, usable default
(like `sync.Mutex`, `bytes.Buffer`).

**Don't panic in libraries.**
Reserve `panic` for truly unrecoverable programmer errors.
Libraries should return errors.

**Keep packages focused.**
One package = one purpose.
Avoid `utils`, `helpers`, `common` packages.

**Name returns only when it aids documentation.**
Named returns clutter code when used just for naked returns.
Use them when the return types need disambiguation
(e.g., `(n int, err error)`).

**Naming conventions:**

When naming functions, types, methods, or variables,
always consult [references/naming-patterns.md](./references/naming-patterns.md)
and follow the matching pattern.

Quick summary:

- Local variables: short (`r`, `w`, `ctx`, `buf`)
- Exported functions/types: descriptive (`ReadConfig`, `HTTPClient`)
- Interfaces: method name + `-er` suffix (`Reader`, `Stringer`, `Closer`)
- No `Get` prefix on getters (`Name()` not `GetName()`)
- Acronyms: all caps (`HTTP`, `ID`, `URL`) — not `Http`, `Id`, `Url`
- Constructors: `New` prefix (`NewReader`), never `Create`
- String-to-type: `Parse` (`ParseInt`), never `From`
- Panic wrappers: `Must` prefix (`MustCompile`)

**Channel direction.**
Specify direction in function signatures:
`func producer() <-chan int`, `func consumer(ch <-chan int)`.

**Context propagation.**
Pass `context.Context` as the first parameter.
Never store it in a struct.

**Use `errgroup` for fail-fast concurrent work.**
When spawning a group of goroutines where one failure should cancel the rest,
use `golang.org/x/sync/errgroup` instead of `sync.WaitGroup` + channels.
`errgroup.WithContext` cancels the shared context on the first error,
so all goroutines can observe it via `ctx.Done()`.

```go
g, ctx := errgroup.WithContext(ctx)
for _, item := range items {
    item := item
    g.Go(func() error {
        return process(ctx, item) // returns on ctx cancel
    })
}
if err := g.Wait(); err != nil {
    return err // first non-nil error
}
```

Use plain `sync.WaitGroup` (or `wg.Go` in Go 1.25+) only when errors
are not expected or are handled inside each goroutine.

**Pre-initialise slices with `append`, not index assignment.**
When the final length is known, use `make([]T, 0, n)` + `append`,
not `make([]T, n)` + index-based filling.

```go
// WRONG — allocate n zero-valued elements, then overwrite by index:
result := make([]string, len(items))
for i, item := range items {
    result[i] = transform(item)
}

// RIGHT — allocate capacity only, fill with append:
result := make([]string, 0, len(items))
for _, item := range items {
    result = append(result, transform(item))
}
```

Why: `make([]T, n)` creates a slice already full of zero values.
If the loop body conditionally skips elements or returns early,
you end up with trailing zero values that silently corrupt results.
`append` with zero length and defined capacity avoids this class of bug
while still performing a single allocation.

**Use type aliases to give maps semantic meaning.**
When a map type like `map[string]map[string]string` is passed between functions,
the keys and values lose their meaning at every call site.
Define a named type for the map and type aliases for its keys and values:

```go
type projectName = string
type alertUUID = string
type alertStatus = string

type ProjectAlertStatuses = map[projectName]map[alertUUID]alertStatus
```

This makes function signatures self-documenting
and eliminates the need for comments explaining what each `string` represents.

```go
// WRONG — caller must guess what each string means:
func Check(statuses map[string]map[string]string) error { ... }

// RIGHT — intent is clear from the types:
func Check(statuses ProjectAlertStatuses) error { ... }
```

Apply this when:

- A map type appears in more than one function signature.
- The map has two or more levels of nesting.
- The key/value types are all primitive (e.g. `string`, `int`) and their
  meaning is unclear.

Do not over-apply — a simple `map[string]bool` used in one place does not need a type alias.

**Struct field ordering.**
Group related fields.
Place `sync.Mutex` or `sync.RWMutex` directly above the fields it protects.

**`sync.RWMutex` — only when reads dominate.**
Default to `sync.Mutex`. Switch to `sync.RWMutex` only when profiling shows
read contention and reads are overwhelmingly more frequent than writes (~90%+).
`RWMutex` has higher internal overhead; for balanced or write-heavy workloads
it is slower than a plain `Mutex`.

```go
type Cache struct {
    mu    sync.RWMutex
    items map[string]string
}

func (c *Cache) Get(key string) (string, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    return c.items[key]
}

func (c *Cache) Set(key, value string) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.items[key] = value
}
```

Never upgrade a read lock to a write lock without releasing first —
it always deadlocks. Release `RUnlock`, then call `Lock`, then re-validate state.

---

## Modern Go Features by Version

### Go 1.18+

**`any` keyword:**
Use `any` instead of `interface{}`.

**`strings.Cut` / `bytes.Cut`:**

```go
before, after, found := strings.Cut(s, "=")
```

Replaces `strings.Index` + manual slicing.

**Generics:**
Use type parameters where they eliminate repetitive code across types.
Don't use generics when a concrete type or interface works just as well.

Never specify type parameters explicitly when the compiler can infer them
from the arguments — which it almost always can for function calls.

```go
// WRONG — redundant, the compiler knows:
slices.Contains[string](items, "foo")
slices.SortFunc[User](users, func(a, b User) int { ... })
result := max[int](a, b)

// RIGHT — let the compiler infer:
slices.Contains(items, "foo")
slices.SortFunc(users, func(a, b User) int { ... })
result := max(a, b)
```

Explicit type parameters are only needed when there are no arguments
to infer from, or when the inferred type would be wrong:

```go
// Necessary — no argument to infer T from:
make([]T, 0)
reflect.TypeFor[MyStruct]()
sync.OnceValue(func() *Config { ... })
```

**`errors.Join`:**

```go
return errors.Join(err1, err2, err3)
```

### Go 1.19+

**`fmt.Appendf`:**

```go
buf = fmt.Appendf(buf, "x=%d", x)
```

Instead of `[]byte(fmt.Sprintf(...))`.

**Type-safe atomics:**

```go
var flag atomic.Bool
flag.Store(true)
if flag.Load() { ... }
```

Instead of `atomic.StoreInt32` / `atomic.LoadInt32`.

### Go 1.20+

**`strings.CutPrefix` / `strings.CutSuffix`:**

```go
if rest, ok := strings.CutPrefix(s, "Bearer "); ok {
    token = rest
}
```

**`context.WithCancelCause`:**

```go
ctx, cancel := context.WithCancelCause(parent)
cancel(fmt.Errorf("timed out waiting for response"))
// later: context.Cause(ctx) returns the error
```

**`errors.Join`:**

```go
err := errors.Join(validateName(n), validateAge(a), validateEmail(e))
```

### Go 1.21+

**Built-in `min` / `max` / `clear`:**

```go
smallest := min(a, b, c)
largest := max(x, y)
clear(myMap)    // delete all entries
clear(mySlice)  // zero all elements
```

DO NOT write custom `min`/`max` helper functions.

**`slices` package:**

- `slices.Contains(items, x)` — not manual loops
- `slices.Sort(items)` — not `sort.Slice`
- `slices.SortFunc(items, func(a, b T) int { return cmp.Compare(a.X, b.X) })`
- `slices.Index(items, x)` — returns index or -1
- `slices.Compact(items)` — remove consecutive duplicates
- `slices.Clone(s)`, `slices.Reverse(items)`, `slices.Max(items)`, `slices.Min(items)`

**`maps` package:**

- `maps.Clone(m)` — not manual iteration
- `maps.Copy(dst, src)`
- `maps.DeleteFunc(m, func(k K, v V) bool { ... })`

**`sync.OnceFunc` / `sync.OnceValue`:**

```go
loadConfig := sync.OnceValue(func() *Config {
    return parseConfig()
})
cfg := loadConfig()
```

Instead of `sync.Once` + wrapper.

**`slog` (structured logging):**

```go
slog.Info("request handled",
    slog.String("method", r.Method),
    slog.Int("status", code),
    slog.Duration("latency", elapsed),
)
```

**`context.AfterFunc`:**

```go
stop := context.AfterFunc(ctx, func() { cleanup() })
defer stop()
```

### Go 1.22+

**Range over integers:**

```go
for i := range 10 {
    fmt.Println(i) // 0..9
}
```

Instead of `for i := 0; i < 10; i++`.

**Loop variable scoping fix:**
Each iteration gets its own copy — no more `v := v` workaround needed.

```go
for _, item := range items {
    go process(item) // safe, each goroutine gets its own copy
}
```

**`cmp.Or` — first non-zero value:**

```go
name := cmp.Or(os.Getenv("APP_NAME"), cfg.Name, "default")
```

Instead of cascading if/else or ternary-like patterns.

**Enhanced `http.ServeMux` — method + path params:**

```go
mux.HandleFunc("GET /api/users/{id}", func(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id")
    // ...
})
mux.HandleFunc("POST /api/users", createUser)
mux.HandleFunc("DELETE /api/users/{id}", deleteUser)
```

**`reflect.TypeFor`:**

```go
typ := reflect.TypeFor[MyStruct]()
```

Instead of `reflect.TypeOf((*MyStruct)(nil)).Elem()`.

**`math/rand/v2`:**
Use `rand/v2` for new code. The `v1` top-level `Seed()` is now a no-op.

### Go 1.23+

**Range over functions (iterators):**

```go
func Backward[E any](s []E) iter.Seq2[int, E] {
    return func(yield func(int, E) bool) {
        for i := len(s) - 1; i >= 0; i-- {
            if !yield(i, s[i]) {
                return
            }
        }
    }
}

for i, v := range Backward(mySlice) {
    fmt.Println(i, v)
}
```

**`maps.Keys` / `maps.Values` return iterators:**

```go
for k := range maps.Keys(m) {
    process(k)
}
keys := slices.Collect(maps.Keys(m))
sortedKeys := slices.Sorted(maps.Keys(m))
```

Instead of manual `for k := range m { keys = append(keys, k) }`.

**`slices.Collect` — materialize iterator to slice:**

```go
items := slices.Collect(someIterator)
```

**`unique` package — value interning:**

```go
h := unique.Make("frequently-used-string")
// h.Value() returns the string; handles are pointer-comparable
```

**Timer/Ticker GC improvement:**
`time.Tick` is now safe to use freely —
unstopped tickers are garbage collected.
No longer a source of leaks.

### Go 1.24+

**`omitzero` JSON struct tag:**

```go
type Config struct {
    Timeout  time.Duration `json:"timeout,omitzero"`
    Deadline time.Time     `json:"deadline,omitzero"`
    Tags     []string      `json:"tags,omitzero"`
}
```

ALWAYS use `omitzero` for `time.Time`, `time.Duration`, structs, slices, maps.
The `omitempty` tag does not work correctly for these types.

**`strings.SplitSeq` / `strings.FieldsSeq` — iterator-based splitting:**

```go
for part := range strings.SplitSeq(s, ",") {
    process(part)
}
```

Use `SplitSeq`/`FieldsSeq` when iterating in a for-range loop.
Also: `bytes.SplitSeq`, `bytes.FieldsSeq`.

**Tool directives in `go.mod`:**

```text
tool golang.org/x/tools/cmd/stringer
```

Replaces the `tools.go` pattern for tracking tool dependencies.

**`os.Root` — directory-scoped filesystem access:**

```go
root, err := os.OpenRoot("/srv/data")
f, err := root.Open("file.txt") // cannot escape /srv/data
```

**`crypto/cipher.NewGCMWithRandomNonce`:**
AES-GCM with automatic nonce generation — eliminates nonce management.

### Go 1.25+

**`wg.Go()` — simplified goroutine spawning:**

```go
var wg sync.WaitGroup
for _, item := range items {
    wg.Go(func() {
        process(item)
    })
}
wg.Wait()
```

ALWAYS use `wg.Go()` instead of
`wg.Add(1)` + `go func() { defer wg.Done(); ... }()`.

**`net/http.CrossOriginProtection` — token-less CSRF:**

```go
csrf := http.NewCrossOriginProtection()
csrf.AddTrustedOrigin("https://app.example.com")
handler := csrf.Handler(mux)
```

**`runtime/trace.FlightRecorder` — continuous low-overhead tracing:**

```go
rec := trace.NewFlightRecorder(trace.FlightRecorderConfig{
    MinAge:   5 * time.Second,
    MaxBytes: 3 << 20,
})
rec.Start()
defer rec.Stop()
// snapshot on interesting events:
rec.WriteTo(file)
```

**Container-aware GOMAXPROCS:**
Runtime auto-adjusts to cgroup CPU limits on Linux.
No code changes needed.

**`encoding/json/v2` (experimental):**
Enable with `GOEXPERIMENT=jsonv2`.
Faster decoding, case-sensitive matching, streaming support.

**`reflect.TypeAssert[T]`:**

```go
person, ok := reflect.TypeAssert[Person](val)
```

Allocation-free alternative to `val.Interface().(T)`.

### Go 1.26+

**`new(expr)` — pointer to any value:**

```go
cfg := Config{
    Timeout: new(30),        // *int
    Debug:   new(true),      // *bool
    Label:   new("prod"),    // *string
}

req := Request{
    Attempts: new(10),
    Deadline: new(time.Now().Add(5 * time.Minute)),
}
```

DO NOT write `ptrTo()`, `intPtr()`, `strPtr()` helper functions.
DO NOT use `x := val; &x` patterns.
Use `new(val)` directly.

**`errors.AsType[T]` — type-safe error matching:**

```go
if pathErr, ok := errors.AsType[*os.PathError](err); ok {
    fmt.Println("path:", pathErr.Path)
}

if connErr, ok := errors.AsType[*net.OpError](err); ok {
    fmt.Println("network op failed:", connErr.Op)
}
```

ALWAYS use `errors.AsType` instead of
`var target *T; errors.As(err, &target)`.

**`slog.NewMultiHandler` — fan-out logging:**

```go
multi := slog.NewMultiHandler(
    slog.NewTextHandler(os.Stdout, nil),
    slog.NewJSONHandler(logFile, nil),
)
logger := slog.New(multi)
```

**Self-referential generic type constraints:**

```go
type Adder[A Adder[A]] interface {
    Add(A) A
}
```

**`go fix` modernizers:**
Run `go fix ./...` after upgrading the toolchain.
Available modernizers include:
`minmax`, `rangeint`, `forvar`, `any`, `stringscut`, `fmtappendf`,
`mapsloop`, `newexpr`, `errorsastype`, `hostport`.

**Reader-less cryptography:**
Crypto functions ignore the `rand` parameter
and always use secure randomness:

```go
key, err := ecdsa.GenerateKey(elliptic.P256(), nil)
```

**`bytes.Buffer.Peek(n)`:**

```go
sample, err := buf.Peek(5) // read without consuming
```

**`reflect` iterator methods:**

```go
for f := range reflect.TypeFor[MyStruct]().Fields() {
    fmt.Println(f.Name, f.Type)
}
```

---

## Common LLM Anti-Patterns

These are patterns LLMs frequently generate that have modern replacements.
DO NOT generate these outdated patterns
when the project's Go version supports the alternative.

**1. Custom `min`/`max` helpers (fixed in 1.21+):**

```go
// WRONG:
func min(a, b int) int { if a < b { return a }; return b }
// RIGHT: use built-in min(a, b)
```

**2. `sort.Slice` instead of `slices.Sort` (fixed in 1.21+):**

```go
// WRONG:
sort.Slice(items, func(i, j int) bool { return items[i] < items[j] })
// RIGHT:
slices.Sort(items)
```

**3. Loop variable capture workaround (fixed in 1.22+):**

```go
// WRONG (unnecessary since 1.22):
for _, v := range items {
    v := v // shadow variable — no longer needed
    go process(v)
}
// RIGHT:
for _, v := range items {
    go process(v)
}
```

**4. Three-clause for loop for simple counting (fixed in 1.22+):**

```go
// WRONG:
for i := 0; i < 10; i++ { ... }
// RIGHT:
for i := range 10 { ... }
```

**5. `interface{}` instead of `any` (fixed in 1.18+):**

```go
// WRONG:
func process(v interface{}) { ... }
// RIGHT:
func process(v any) { ... }
```

**6. Manual map key collection (fixed in 1.23+):**

```go
// WRONG:
keys := make([]string, 0, len(m))
for k := range m {
    keys = append(keys, k)
}
// RIGHT:
keys := slices.Collect(maps.Keys(m))
```

**7. `omitempty` for time/struct/slice types (fixed in 1.24+):**

```go
// WRONG:
Timeout time.Duration `json:"timeout,omitempty"` // doesn't work correctly
// RIGHT:
Timeout time.Duration `json:"timeout,omitzero"`
```

**8. WaitGroup boilerplate (fixed in 1.25+):**

```go
// WRONG:
wg.Add(1)
go func() {
    defer wg.Done()
    doWork()
}()
// RIGHT:
wg.Go(func() { doWork() })
```

**9. Pointer-to-value helper functions (fixed in 1.26+):**

```go
// WRONG:
func ptr[T any](v T) *T { return &v }
cfg := Config{Retries: ptr(3)}
// RIGHT:
cfg := Config{Retries: new(3)}
```

**10. `errors.As` with pre-declared variable (fixed in 1.26+):**

```go
// WRONG:
var target *MyError
if errors.As(err, &target) { ... }
// RIGHT:
if target, ok := errors.AsType[*MyError](err); ok { ... }
```

**11. `fmt.Sprintf("%s:%d", host, port)` for network addresses (all versions):**

```go
// WRONG — breaks with IPv6:
addr := fmt.Sprintf("%s:%d", host, port)
// RIGHT:
addr := net.JoinHostPort(host, strconv.Itoa(port))
```

**12. `ReverseProxy.Director` (deprecated in 1.26+):**

```go
// WRONG:
proxy := &httputil.ReverseProxy{Director: func(req *http.Request) { ... }}
// RIGHT:
proxy := &httputil.ReverseProxy{Rewrite: func(r *httputil.ProxyRequest) { ... }}
```

**13. Passing `rand.Reader` to crypto functions (fixed in 1.26+):**

```go
// WRONG:
key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
// RIGHT:
key, err := ecdsa.GenerateKey(elliptic.P256(), nil)
```

**14. `errors.Wrap` from `pkg/errors` / `xerrors.Errorf` from `x/xerrors` (all versions):**

```go
// WRONG — obsolete third-party packages:
return errors.Wrap(err, "open config")
return xerrors.Errorf("open config: %w", err)
// RIGHT — standard library since Go 1.13:
return fmt.Errorf("open config: %w", err)
```
