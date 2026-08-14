# Go Naming Patterns

Choose names from the concept and the surrounding package. Standard-library
patterns are evidence, not mechanical laws.

## General Rules

- Use `MixedCaps` or `mixedCaps` for ordinary Go identifiers.
- Keep initialism casing consistent: `URL`/`url`, `HTTP`/`http`, and `ID`/`id`,
  not `Url`, `Http`, or `Id`. Follow an established public API when
  compatibility requires its spelling.
- Match name length to scope and ambiguity. Short names such as `i`, `r`, or
  `ctx` work in small, conventional scopes. Use descriptive names as scope or
  competing concepts grow.
- Name constants by role, not by literal value. Go code normally uses mixed
  caps, but generated bindings and identifiers mirroring an external protocol
  can legitimately preserve underscore-based names.
- Avoid package stutter: prefer `http.Server` to `http.HTTPServer`.
- Read names at call sites. A locally plausible name can become redundant or
  misleading after package qualification.

## Construction and Conversion

### `New`

`New` is the usual name for a constructor that initializes a Go value. It may
return a value, pointer, interface, or value-plus-error; it does not imply a
pointer.

When a package centers on one type, `New` can be enough. Use names such as
`NewReader` or `NewRequest` when the package constructs several concepts.

Do not ban `Create`. It often signals creation of an external or persistent
resource, as in `os.Create`, and can be correct when that side effect is the
operation's defining behavior. Distinguish value construction from domain
resource creation.

### `Must`

`MustX` often parallels a fallible `X` and panics on failure. A helper such as
`template.Must` instead accepts the `(T, error)` result of another call. Use the
pattern only when failure means a programmer-controlled input or invariant is
invalid and the panic contract is explicit. Package initialization and fixed
test fixtures are common uses, not the only possible ones.

Do not use `Must` for runtime input, network state, filesystem state, or another
failure that a caller should handle.

### Parsing and formatting

- `Parse` commonly converts validated text into a typed value, such as
  `time.Parse` or `strconv.ParseInt`.
- `Format` commonly converts a value to a controlled textual form.
- `String` commonly provides a human-readable representation or implements
  `fmt.Stringer`.
- `Append` commonly writes a representation into an existing byte slice.

Do not prohibit every `From` name. A domain API may use it to describe an
origin or a conversion that is not textual parsing. Prefer the conventional
verb when its semantics fit.

### Marshal, encode, and write

The standard library often uses these distinctions:

| Family | Common shape |
| --- | --- |
| `Marshal` / `Unmarshal` | Complete in-memory representation and value |
| `Encode` / `Decode` | Encoder or decoder operation, often streaming |
| `Read` / `Write` | Byte or resource I/O |
| `Format` / `Sprint` | Return a string |
| `Fprint` | Write formatted data to an `io.Writer` |
| `Append` | Append formatted data to a byte slice |

These are conventions, not guarantees. Check the type's contract. For example,
an encoder can buffer, and a custom domain may use `Encode` for an in-memory
result.

## Accessors and Predicates

- A simple Go getter normally uses the field concept: `Owner()`, not
  `GetOwner()`.
- A setter normally uses `SetOwner`.
- `Is` often asks about state or identity: `filepath.IsAbs`, `errors.Is`.
- `Has` often asks about containment: `strings.HasPrefix`.
- A clear predicate verb may need no prefix: `strings.Contains`, `utf8.Valid`,
  or `json.Valid`.

Use `errors.Is(err, fs.ErrNotExist)` and related sentinel matching for modern
error-chain-aware checks. Legacy helpers such as `os.IsNotExist` still exist but
should not define new API naming guidance.

## Options and Derived Values

`With` often names either a derived value (`context.WithTimeout`) or a
functional option (`WithLogger`). A functional option should state what it
changes and should not hide required configuration that belongs in an explicit
constructor argument or configuration type.

## Lifecycle and Resources

<!-- markdownlint-disable MD013 -->
| Verb | Common meaning | Qualification |
| --- | --- | --- |
| `Run` | Execute, often until completion | Blocking behavior must be documented |
| `Start` | Begin work | Often non-blocking, but not guaranteed by the word alone |
| `Stop` | Stop background activity | State whether it waits and whether reuse is allowed |
| `Close` | Release a resource | State idempotency and error behavior |
| `Shutdown` | Graceful, coordinated stop | Usually accepts a deadline or context |
| `Reset` | Restore an initial reusable state | It need not equal the language zero value |
| `Flush` | Push buffered data onward | It can fail and may not close anything |
| `Open` | Open or acquire a named resource | It does not universally mean read-only |
| `Create` | Create a value or external resource | Make side effects clear |
| `Dial` | Establish an outbound connection | Network and address semantics belong in the contract |
| `Listen` | Acquire an inbound listener | It does not itself imply serving |
<!-- markdownlint-enable MD013 -->

`Register` means adding an entry to a registry. The registry can be global,
receiver-owned, or explicitly passed. The name alone does not imply global
state.

`Ensure` has no precise standard-library-wide contract. If used, document
whether it creates, verifies, repairs, or is idempotent.

## Operation Families

Use established pairs and families when their contracts match:

- `Read` / `Write`, `ReadFile` / `WriteFile`, `Copy`
- `Serve`, `ServeHTTP`, `Handle`, `HandleFunc`
- `Query`, `QueryRow`, `Exec`, `Prepare`
- `Begin`, `Commit`, `Rollback`
- `Do` for one complete action
- `Walk`, `Visit`, or `Inspect` for traversal styles
- `Validate` for a detailed failure and `Valid` for a Boolean predicate
- `Lock` / `Unlock`, `RLock` / `RUnlock`, and `TryLock`

Use a `Context` suffix when maintaining a context-free sibling API requires it,
as in `QueryContext`. For a new API without such a sibling, an ordinary method
can accept `context.Context` without encoding that fact in its name.

## Interfaces

Name an interface for the behavior it represents:

- A natural one-method interface often uses the method name plus `-er`, such as
  `Reader`, `Writer`, or `Stringer`.
- Compose established capabilities when the combination is meaningful, such as
  `ReadCloser`.
- Use a domain noun for a cohesive protocol that is not naturally named after
  one method, such as `Handler` or `RoundTripper`.

Do not force an awkward `-er` name, and do not infer that every interface must
have one method. Define a consumer-specific interface near that consumer by
default; use the interface-design guidance for valid shared or producer-owned
contracts.

## Errors

- Exported sentinel errors conventionally start with `Err`, such as
  `ErrClosed`.
- Error types usually describe the failure and often end in `Error`, such as
  `PathError`.
- Error strings normally start lowercase and omit trailing punctuation so they
  compose when wrapped. A proper noun or acronym at the start can retain its
  required capitalization.
- Include an operation or resource when it adds diagnostic value. Avoid
  repeating information already supplied by the wrapped error.

## Packages and Receivers

- Package names are normally short, lowercase, and free of underscores.
- Prefer a name that describes one cohesive capability. Names such as `util`,
  `common`, `types`, or `api` are weak when they merely collect unrelated code,
  but they are not forbidden when they accurately name a domain boundary.
- Receiver names are short, consistent abbreviations for the receiver type.
  Avoid `this` or `self`; they add no Go-specific information.

## Tests

- Use `TestX`, `BenchmarkX`, `FuzzX`, and valid `Example` naming so the Go tool
  discovers the intended function.
- Give subtests concise names that identify the behavior or case.
- Call `t.Helper()` in helpers that report through `testing.TB`.
- Prefer `Fatal`, `Error`, or returned errors in test helpers. A helper named
  `mustParse` need not panic; it can call `t.Helper()` and `t.Fatal` so the test
  failure is reported correctly.
- Use `t.Cleanup` for cleanup tied to a test's lifetime.

## Common Misapplications

| Misapplication | Better decision |
| --- | --- |
| Every constructor returns a pointer | Return the representation the API needs |
| `Create` is always wrong | Reserve it for semantics that genuinely mean create |
| Every text conversion is `Parse` | Use `Parse` when validation of textual syntax is central |
| Every interface ends in `-er` | Use a natural behavior or domain name |
| Every short variable is idiomatic | Match length to scope and ambiguity |
| Underscores never appear in Go names | Allow generated or externally constrained identifiers |
| `Open` means read-only | Document access mode; the verb only signals acquisition |
| `Register` means global mutation | Identify the registry and ownership explicitly |
| `Ensure` guarantees idempotency | State the actual behavior in the contract |

## Official and Primary Sources

- [Effective Go](https://go.dev/doc/effective_go)
- [Go Wiki: Code Review Comments](https://go.dev/wiki/CodeReviewComments)
- [Go Blog: Package Names](https://go.dev/blog/package-names)
- [Google Go Style Guide: Decisions](https://google.github.io/styleguide/go/decisions)
- [Google Go Style Guide: Best Practices](https://google.github.io/styleguide/go/best-practices)
