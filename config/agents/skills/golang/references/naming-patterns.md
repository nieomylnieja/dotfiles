# Go Naming Patterns

Standard library naming patterns for functions, types, and variables.
When naming something,
find the matching pattern here and follow it.

## General Rules

- **MixedCaps** — Always `MixedCaps` or `mixedCaps`, never underscores.
- **Initialisms** — Consistent case: `URL`/`url`, `HTTP`/`http`, `ID`/`id`.
  Never `Url`, `Http`, `Id`.
- **Length proportional to scope**
  Short for small scopes (`i`, `c`, `r`),
  longer for larger scopes (`requestCount`, `defaultTimeout`).
- **Constants** — `MixedCaps` like everything else,
  never `UPPER_SNAKE_CASE`.
  Name by role, not value.

## Function Verb Patterns

### Constructors

**`New`** — Standard constructor.
Returns a pointer.
When the package exports one primary type, use just `New`.

```go
bufio.NewReader(r)       // *bufio.Reader
list.New()               // *list.List — only type in package
http.NewRequest(...)     // *http.Request
http.NewServeMux()       // *http.ServeMux
```

Never `Create` for constructors.
`Create` means resource creation with side effects
(`os.Create` creates a file on disk).

**`Must`** — Panic on error.
Wraps a fallible function,
panics instead of returning error.
Only for package-level init or test setup.

```go
regexp.MustCompile(`\d+`)
template.Must(template.New("x").Parse(src))
```

Convention: `MustX` wraps `X` which returns `(T, error)`.

### Conversion

**`Parse`** — String to type. NEVER use `From`.

```go
strconv.ParseInt(s, base, bitSize)  // not IntFromString
strconv.ParseFloat(s, bitSize)      // not FloatFromString
strconv.ParseBool(s)                // not BoolFromString
time.Parse(layout, value)           // not TimeFromString
time.ParseDuration("10s")           // not DurationFromString
net.ParseIP(s)                      // not IPFromString
net.ParseCIDR(s)                    // not CIDRFromString
url.Parse(rawURL)                   // not URLFromString
```

**`Format`** — Type to string.

```go
strconv.FormatInt(i, base)
strconv.FormatFloat(f, fmt, prec, bitSize)
strconv.FormatBool(b)
```

**Three output families:**

| Pattern   | Returns          | Example                            |
|-----------|------------------|------------------------------------|
| `Format*` | `string`         | `strconv.FormatInt`                |
| `Sprint*` | `string`         | `fmt.Sprint`, `fmt.Sprintf`        |
| `Fprint*` | writes to Writer | `fmt.Fprint`, `fmt.Fprintf`        |
| `Append*` | `[]byte`         | `strconv.AppendInt`, `fmt.Appendf` |

**`Encode`/`Decode` vs `Marshal`/`Unmarshal`:**

- **Marshal/Unmarshal** — Complete in-memory data (`[]byte` ↔ struct).
- **Encode/Decode** — Streams (`io.Reader`/`io.Writer` ↔ struct).

```go
json.Marshal(v)                    // struct → []byte
json.Unmarshal(data, &v)           // []byte → struct

json.NewEncoder(w).Encode(v)      // struct → io.Writer
json.NewDecoder(r).Decode(&v)     // io.Reader → struct
```

Custom serialization interfaces:
`MarshalJSON`/`UnmarshalJSON`,
`MarshalText`/`UnmarshalText`.

### Accessors

- **Getters — NO `Get` prefix.**
  The getter is the field name, capitalized.
  `obj.Owner()` not `obj.GetOwner()`.
- **Setters — `Set` prefix.**
  `obj.SetOwner(user)`.

### Predicates

**`Is`** — Identity / state check:

```go
filepath.IsAbs(path)
os.IsExist(err)
os.IsNotExist(err)
os.IsPermission(err)
strconv.IsPrint(r)
```

**`Has`** — Containment:

```go
strings.HasPrefix(s, prefix)
strings.HasSuffix(s, suffix)
```

**No prefix** when the verb is clear:

```go
strings.Contains(s, substr)
strings.EqualFold(s, t)
utf8.Valid(p)
json.Valid(data)
sort.IsSorted(data) // exception: reads naturally with Is
```

### Functional Options

**`With`** — Create derived value or add option:

```go
context.WithCancel(parent)
context.WithTimeout(parent, d)
context.WithValue(parent, key, val)
```

Functional options pattern:

```go
func WithTimeout(d time.Duration) Option { ... }
func WithLogger(l *log.Logger) Option { ... }
func NewClient(opts ...Option) *Client { ... }
```

### Lifecycle

| Verb       | Meaning                                      | Example                      |
|------------|----------------------------------------------|------------------------------|
| `Run`      | Blocking execution, returns when done        | `cmd.Run()`                  |
| `Start`    | Non-blocking, begins background work         | `cmd.Start()`                |
| `Stop`     | Stop background work                         | `server.Stop()`              |
| `Close`    | Release resources (`io.Closer`)              | `file.Close()`, `db.Close()` |
| `Shutdown` | Graceful shutdown                            | `http.Server.Shutdown(ctx)`  |
| `Reset`    | Reinitialize to zero/initial state           | `bytes.Buffer.Reset()`       |
| `Flush`    | Flush buffered data                          | `bufio.Writer.Flush()`       |
| `Init`     | Explicit initialization (rare, prefer `New`) | `init()` auto-called         |

### I/O

| Verb        | Meaning               | Example                          |
|-------------|-----------------------|----------------------------------|
| `Read`      | Read bytes            | `io.Reader.Read(p)`              |
| `Write`     | Write bytes           | `io.Writer.Write(p)`             |
| `ReadFile`  | Read entire file      | `os.ReadFile(name)`              |
| `WriteFile` | Write entire file     | `os.WriteFile(name, data, perm)` |
| `ReadAll`   | Read all from reader  | `io.ReadAll(r)`                  |
| `Copy`      | Copy reader to writer | `io.Copy(dst, src)`              |

`String` suffix for string variants:
`WriteString`, `MatchString`, `FindString`, `ReplaceAllString`.

### Resources

| Verb     | Meaning                           | Example                     |
|----------|-----------------------------------|-----------------------------|
| `Open`   | Acquire read-only resource        | `os.Open(name)`             |
| `Create` | Create resource with side effects | `os.Create(name)`           |
| `Close`  | Release resource                  | `file.Close()`              |
| `Dial`   | Outbound network connection       | `net.Dial(network, addr)`   |
| `Listen` | Accept inbound connections        | `net.Listen(network, addr)` |

### Network / HTTP

| Verb             | Meaning                           | Example                              |
|------------------|-----------------------------------|--------------------------------------|
| `Serve`          | Start serving (blocking)          | `http.Serve(ln, handler)`            |
| `ListenAndServe` | Listen + serve                    | `http.ListenAndServe(addr, handler)` |
| `Handle`         | Register handler                  | `mux.Handle(pattern, handler)`       |
| `HandleFunc`     | Register handler function         | `mux.HandleFunc(pattern, fn)`        |
| `ServeHTTP`      | Handle single request (interface) | `Handler.ServeHTTP(w, r)`            |
| `Register`       | Global registration (drivers)     | `sql.Register(name, driver)`         |

### Database

| Verb       | Meaning                | Example                   |
|------------|------------------------|---------------------------|
| `Query`    | Returns multiple rows  | `db.Query(q, args...)`    |
| `QueryRow` | Returns single row     | `db.QueryRow(q, args...)` |
| `Exec`     | No rows returned       | `db.Exec(q, args...)`     |
| `Prepare`  | Prepared statement     | `db.Prepare(q)`           |
| `Begin`    | Start transaction      | `db.Begin()`              |
| `Commit`   | Commit transaction     | `tx.Commit()`             |
| `Rollback` | Rollback transaction   | `tx.Rollback()`           |
| `Scan`     | Read structured fields | `rows.Scan(&id, &name)`   |
| `Ping`     | Liveness check         | `db.Ping()`               |

`*Context` suffix for context-aware variants:
`QueryContext`, `ExecContext`.

### Execution and Traversal

| Verb      | Meaning                           | Example                                  |
|-----------|-----------------------------------|------------------------------------------|
| `Do`      | Execute single action             | `http.Client.Do(req)`, `sync.Once.Do(f)` |
| `Apply`   | Apply configuration/transform     | `astutil.Apply(root, pre, post)`         |
| `Walk`    | Traverse tree with callback       | `filepath.WalkDir(root, fn)`             |
| `Inspect` | Simplified walk (functional)      | `ast.Inspect(node, f)`                   |
| `Visit`   | Visitor pattern (interface-based) | `ast.Walk(visitor, node)`                |

### Validation

| Verb       | Meaning                                           |
|------------|---------------------------------------------------|
| `Validate` | Returns error if invalid                          |
| `Valid`    | Returns bool (stdlib: `json.Valid`, `utf8.Valid`) |
| `Check`    | Less common, sometimes bool                       |
| `Ensure`   | Idempotent: make it so if not already             |

### Synchronization

```go
sync.Mutex.Lock() / Unlock()
sync.Mutex.TryLock()              // non-blocking (1.18+)
sync.RWMutex.RLock() / RUnlock()  // read lock
sync.RWMutex.Lock() / Unlock()    // write lock
```

## Identifier Naming

### Interfaces

**One-method** — method name + `-er`:

```go
Reader, Writer, Closer, Seeker, Stringer, Formatter, Scanner,
Marshaler, Unmarshaler
```

**Composite** — concatenate:

```go
ReadWriter, ReadCloser, WriteCloser, ReadWriteCloser, ReadSeeker
```

**Multi-method / broad scope** — noun:

```go
Handler, RoundTripper, Conn
```

Interfaces belong in the **consumer** package,
not the producer.

### Stringer and Error Interfaces

- `String() string` — implement for `fmt` formatting.
  Use `String` not `ToString`.
- `Error() string` — implement for `error` interface.
- `GoString() string` — for `%#v` formatting.

### Errors

**Sentinel variables** — `Err` prefix + noun/adjective:

```go
var ErrNotExist = errors.New("file does not exist")
var ErrPermission = errors.New("permission denied")
var ErrClosed = errors.New("already closed")
var ErrInvalid = errors.New("invalid argument")
```

**Error types** — descriptive name, often ending in `Error`:

```go
type PathError struct { Op, Path string; Err error }
type SyntaxError struct { Offset int64; msg string }
type NumError struct { Func, Num string; Err error }
type UnmarshalTypeError struct { ... }
```

**Error strings** — lowercase, no punctuation, composable:

```go
fmt.Errorf("open config: %w", err) // correct
fmt.Errorf("Open config.")         // wrong
```

### Packages

- Lowercase, single-word, no underscores or mixedCaps.
- Don't repeat package name in identifiers:
  `http.Server` not `http.HTTPServer`.
- One primary type → constructor is `New()`.
- Avoid meaningless names:
  `util`, `common`, `misc`, `api`, `types`, `interfaces`.

### Receivers

- One or two letter abbreviation:
  `c` for `Client`, `s` for `Server`.
- Consistent across all methods of the type.
- Never `self`, `this`, or `me`.

### Tests

- Tests: `TestFunctionName`, `Test_unexportedName`.
- Subtests: `t.Run("descriptive name", ...)`.
- Benchmarks: `BenchmarkFunctionName`.
- Examples: `ExampleFunctionName`, `ExampleType_Method`.
- Test helpers: mark with `t.Helper()`.
- Test doubles package: append `test` — `creditcardtest`.
- Must helpers in tests:
  `mustParse`, `mustMarshal` (panic on failure).
- Setup/teardown:
  use `t.Cleanup(func())`, not explicit methods.

## Anti-Patterns

| Wrong           | Right           | Reason                        |
|-----------------|-----------------|-------------------------------|
| `FromString`    | `Parse`         | Go convention for string→type |
| `ToString`      | `String()`      | Stringer interface            |
| `CreateReader`  | `NewReader`     | `New` for constructors        |
| `GetName()`     | `Name()`        | No `Get` prefix on getters    |
| `UPPER_SNAKE`   | `MixedCaps`     | Go never uses underscore case |
| `Url`, `Http`   | `URL`, `HTTP`   | Initialisms are all-caps      |
| `self`/`this`   | `c`/`s`/`re`    | Short receiver names          |
| `utils` package | focused package | Packages have single purpose  |

## Sources

- [Effective Go](https://go.dev/doc/effective_go) —
  official guide to writing clear, idiomatic Go
- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments) —
  common code review feedback collected by the Go team
- [Go Blog — Package Names](https://go.dev/blog/package-names) —
  conventions for naming Go packages
- [Google Go Style Guide — Decisions](https://google.github.io/styleguide/go/decisions) —
  naming, formatting, and style decisions
- [Google Go Style Guide — Best Practices](https://google.github.io/styleguide/go/best-practices) —
  patterns for functional options, config structs, and more
