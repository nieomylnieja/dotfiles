---
name: golang-testing
description: >
  Use this skill when writing or modifying Go tests, benchmarks, or test
  helpers. Covers test style, modern testing APIs, and common mistakes.
---

# Go Version Detection

<!-- markdownlint-disable-next-line MD013 -->
!`grep -rh "^go " --include="go.mod" . 2>/dev/null | cut -d' ' -f2 | sort | uniq -c | sort -nr | head -1 | xargs | cut -d' ' -f2 | grep . || echo unknown`

Use ONLY the version shown above to determine which testing APIs are available.

---

## Test File Layout

**HARD RULE: Test functions MUST appear before any utility/helper functions.**

Order test files top-to-bottom:

1. **Test functions** (`Test*`, `Benchmark*`, `Fuzz*`, `Example*`)
2. **Test helpers** (functions calling `t.Helper()`)
3. **Utility functions** (builders, fakes, assertion helpers, fixtures)

Never place utility or helper code above the tests that use it.
The tests are what readers care about — helpers are implementation details.

---

## Test Naming

### Test Functions

`TestXxx` where Xxx does not start with a lowercase letter.
Underscores are allowed in test names (exception to general Go naming).

| Pattern | Use Case | Example |
| --- | --- | --- |
| `TestFunction` | Exported function | `TestParse`, `TestMarshalJSON` |
| `TestType_Method` | Method on a type | `TestReader_Read`, `TestConfig_Validate` |
| `Test_unexported` | Unexported function | `Test_parseHeader`, `Test_resolve` |

There is no enforced 1:1 mapping between test and production functions.
Name tests for what they verify, not which function they call.

### Subtests (`t.Run`)

Subtest names are slash-joined to the parent: `TestParse/empty_input`.
Spaces become underscores in output. Slashes create hierarchy levels.

```go
// GOOD — describes the condition being tested:
t.Run("nil input", func(t *testing.T) { ... })
t.Run("duplicate keys", func(t *testing.T) { ... })
t.Run("trailing slash", func(t *testing.T) { ... })

// BAD:
t.Run("test 1", func(t *testing.T) { ... })      // meaningless number
t.Run("", func(t *testing.T) { ... })             // empty name
t.Run(fmt.Sprintf("%v", input), func(...) { ... }) // unreadable after escaping
```

The `-run` flag matches each `/`-separated level with an unanchored regex:

```bash
go test -run=TestParse/empty        # parent + subtest
go test -run=TestParse/             # all subtests of TestParse
```

### Table-Driven Test Cases

Always provide a descriptive name. Never use index-based identification.
Prefer map-keyed tables when test order does not matter.

```go
// GOOD — map key is the test name:
tests := map[string]struct {
    in       string
    expected int
}{
    "positive": {in: "42", expected: 42},
    "zero":     {in: "0", expected: 0},
    "negative": {in: "-1", expected: -1},
}

// BAD — forces reader to count entries:
for i, tt := range tests {
    t.Run(fmt.Sprintf("case_%d", i), func(t *testing.T) { ... })
}
```

Case name guidelines:

- **Describe the condition**, not the outcome: `"nil map"` not `"returns error"`
- **Keep short but specific**: `"empty slice"`, `"UTF-8 multibyte"`
- **Do not repeat the function name** — the parent `TestXxx` already identifies it
- **Avoid numbering**: `"case 1"` forces counting to find failures

### Examples

Example names are strictly enforced — they control where `go doc` renders them:

| Pattern | Documents |
| --- | --- |
| `Example()` | Package |
| `ExampleFoo()` | Function `Foo` |
| `ExampleBar_Baz()` | Method `Baz` on type `Bar` |
| `ExampleFoo_suffix()` | Additional example (suffix starts lowercase) |

### Naming Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| `TestFoo1`, `TestFoo2` | Numbered — conveys nothing | `TestFoo_NilInput`, `TestFoo_EmptySlice` |
| `TestHappy` | Too vague — happy path of what? | `TestParse_ValidJSON` |
| `TestParseParsesProperly` | Repeats function name | `TestParse` or `TestParse_ValidInput` |
| Very long names | Unreadable in output | Shorten; use subtests for breakdown |
| `Testparse` | Lowercase after `Test` | Won't be discovered by `go test` |

---

## Test Style

- Use table-driven tests with subtests (`t.Run`)
- Call `t.Helper()` in test helper functions
  so failure lines point to the call site, not the helper
- Call `t.Parallel()` at the top of tests that are independent
- Store test fixtures in a `testdata/` directory
- Be aware of build tags like `//go:build unit_test` —
  if present, include them in build and test commands

---

## Table-Driven Tests

Table-driven tests are the default pattern for testing multiple inputs/outputs.
Every table test needs: a struct defining the test case,
a collection of named cases,
and a loop calling `t.Run`.

### Basic Structure (Map-Keyed)

Prefer map-keyed tables when test execution order does not matter.
The map key is the test name — no `name` struct field needed.
Randomized iteration can expose order-dependent bugs.

```go
func TestReverse(t *testing.T) {
    tests := map[string]struct {
        in       string
        expected string
    }{
        "empty":      {in: "", expected: ""},
        "single char": {in: "a", expected: "a"},
        "palindrome": {in: "aba", expected: "aba"},
        "ascii":      {in: "hello", expected: "olleh"},
    }
    for name, tt := range tests {
        t.Run(name, func(t *testing.T) {
            got := Reverse(tt.in)
            assert.Equal(t, tt.expected, got)
        })
    }
}
```

### Basic Structure (Slice)

Use a slice when execution order matters (e.g. sequential dependencies).
Requires an explicit `name` field.

```go
func TestMigrations(t *testing.T) {
    tests := []struct {
        name     string
        in       string
        expected string
    }{
        {name: "v1 to v2", in: "v1", expected: "v2"},
        {name: "v2 to v3", in: "v2", expected: "v3"},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Migrate(tt.in)
            assert.Equal(t, tt.expected, got)
        })
    }
}
```

### With Error Cases

When testing both success and error paths, add an `expectedErr` field.
Use `require` for error checks before accessing the result.

```go
func TestParsePort(t *testing.T) {
    tests := map[string]struct {
        in          string
        expected    int
        expectedErr string
    }{
        "valid":        {in: "8080", expected: 8080},
        "zero":         {in: "0", expected: 0},
        "negative":     {in: "-1", expectedErr: "out of range"},
        "not a number": {in: "abc", expectedErr: "invalid syntax"},
    }
    for name, tt := range tests {
        t.Run(name, func(t *testing.T) {
            got, err := ParsePort(tt.in)
            if tt.expectedErr != "" {
                require.ErrorContains(t, err, tt.expectedErr)
                return
            }
            require.NoError(t, err)
            assert.Equal(t, tt.expected, got)
        })
    }
}
```

### With Setup/Teardown per Case

When cases need individual setup, use a function field:

```go
tests := []struct {
    name  string
    setup    func(t *testing.T) *Config
    expected string
}{
    {
        name: "default config",
        setup: func(t *testing.T) *Config {
            return NewConfig()
        },
        expected: "localhost",
    },
    {
        name: "custom host",
        setup: func(t *testing.T) *Config {
            c := NewConfig()
            c.Host = "example.com"
            return c
        },
        expected: "example.com",
    },
}
```

### Parallel Table Tests

Call `t.Parallel()` in both the parent and each subtest.
Capture the loop variable (required before Go 1.22):

```go
func TestFetch(t *testing.T) {
    t.Parallel()
    tests := map[string]struct {
        url      string
        expected int
    }{
        "ok":        {url: "/ok", expected: 200},
        "not found": {url: "/missing", expected: 404},
    }
    for name, tt := range tests {
        t.Run(name, func(t *testing.T) {
            t.Parallel()
            got := fetch(tt.url)
            assert.Equal(t, tt.expected, got)
        })
    }
}
```

### When NOT to Use Table Tests

Not everything belongs in a table. Avoid tables when:

- Each case requires substantially different setup or assertions
- The test has only 1-2 cases — a plain test is simpler
- The struct would need many optional fields, most `nil` per case

In these situations, write separate `TestXxx` functions or
inline subtests instead of forcing a table structure.

---

## Testify: `assert` vs `require`

Use `github.com/stretchr/testify` for assertions.
It provides two packages with identical APIs:

- **`assert`** — logs the failure and continues the test
- **`require`** — logs the failure and stops the test immediately (`t.FailNow()`)

**Rule: use `require` whenever subsequent code would panic or be meaningless
if the assertion fails.**

Common cases where `require` is mandatory:

- Checking `err == nil` before using the result
- Checking a pointer/slice/map is non-nil before indexing into it
- Checking a type assertion succeeded before using the typed value
- Any setup step that must succeed for the rest of the test to be valid

```go
func TestUserService(t *testing.T) {
    user, err := service.CreateUser("alice")
    require.NoError(t, err)       // stop here if err != nil
    require.NotNil(t, user)       // stop here if user == nil

    // safe to dereference now
    assert.Equal(t, "alice", user.Name)
    assert.NotEmpty(t, user.ID)
    assert.True(t, user.CreatedAt.After(time.Time{}))
}
```

Contrast with using `assert` for everything — the test would panic on `user.Name`
if `CreateUser` returned `nil, err`:

```go
// WRONG — panics if user is nil:
assert.NoError(t, err)
assert.Equal(t, "alice", user.Name) // nil dereference
```

**Table-driven test with `require`:**

```go
func TestParse(t *testing.T) {
    tests := map[string]struct {
        input    string
        expected int
    }{
        "positive": {input: "42", expected: 42},
        "zero":     {input: "0", expected: 0},
    }
    for name, tt := range tests {
        t.Run(name, func(t *testing.T) {
            got, err := parse(tt.input)
            require.NoError(t, err) // skip remaining assertions on failure
            assert.Equal(t, tt.expected, got)
        })
    }
}
```

**Common `require`/`assert` functions:**

| Function | Use when |
| --- | --- |
| `require.NoError(t, err)` | must succeed before using result |
| `require.NotNil(t, v)` | must be non-nil before dereferencing |
| `require.Len(t, s, n)` | must have length before indexing |
| `assert.Equal(t, expected, got)` | value comparison |
| `assert.ErrorIs(t, err, target)` | error chain check |
| `assert.Contains(t, s, sub)` | substring / element presence |
| `assert.Eventually(t, cond, timeout, tick)` | async condition |

---

## Modern Testing APIs by Version

### Go 1.24+

**`t.Context()` — test-scoped context:**

```go
func TestFoo(t *testing.T) {
    ctx := t.Context() // canceled when test ends
    result := doSomething(ctx)
}
```

ALWAYS use `t.Context()` instead of
`context.WithCancel(context.Background())` in tests.

**`b.Loop()` — benchmark main loop:**

```go
func BenchmarkFoo(b *testing.B) {
    for b.Loop() {
        doWork()
    }
}
```

ALWAYS use `b.Loop()` instead of `for i := 0; i < b.N; i++`.
Prevents compiler over-optimization and runs setup/teardown only once.

**`t.Chdir(dir)` — change working directory for test duration:**

```go
func TestConfig(t *testing.T) {
    t.Chdir(t.TempDir())
    // working directory is restored after test
}
```

### Go 1.25+

**`testing/synctest` — virtualized time for concurrent tests:**

```go
func TestTimeout(t *testing.T) {
    synctest.Test(t, func(t *testing.T) {
        ch := make(chan int)
        go func() {
            time.Sleep(5 * time.Second) // virtual, instant
            ch <- 42
        }()
        synctest.Wait() // waits until all goroutines block
        select {
        case v := <-ch:
            fmt.Println("got", v)
        case <-time.After(10 * time.Second):
            t.Fatal("timed out")
        }
    })
}
```

Key points:

- `synctest.Test(t, fn)` runs `fn` in an isolated bubble with virtualized time
- The fake clock advances when all goroutines in the bubble are blocked
- `synctest.Wait()` waits for all goroutines to reach a blocking state
- No real wall-clock time is consumed

**`t.Attr()` / `t.Output()` — structured test output:**

```go
func TestFeature(t *testing.T) {
    t.Attr("issue", "PROJ-1234")
    t.Attr("component", "auth")

    log := slog.New(slog.NewTextHandler(t.Output(), nil))
    log.Info("test log goes to test output, properly indented")
}
```

### Go 1.26+

**`t.ArtifactDir()` — store test output artifacts:**

```go
func TestGenerate(t *testing.T) {
    dir := t.ArtifactDir()
    os.WriteFile(filepath.Join(dir, "output.png"), data, 0644)
    // run with: go test -v -artifacts -outputdir=/tmp/results
}
```

**`testing/cryptotest.SetGlobalRandom()` — deterministic crypto in tests:**

```go
func TestCrypto(t *testing.T) {
    cryptotest.SetGlobalRandom(t, 42) // seed for reproducibility
    key, _ := ecdsa.GenerateKey(elliptic.P256(), nil)
}
```

---

## Common LLM Anti-Patterns

**`context.Background()` in tests (fixed in 1.24+):**

```go
// WRONG:
ctx, cancel := context.WithCancel(context.Background())
defer cancel()
// RIGHT:
ctx := t.Context()
```

**`for i := 0; i < b.N; i++` in benchmarks (fixed in 1.24+):**

```go
// WRONG:
for i := 0; i < b.N; i++ { doWork() }
// RIGHT:
for b.Loop() { doWork() }
```

**Vague or numbered test names:**

```go
// WRONG:
func TestParse1(t *testing.T) { ... }
func TestParse2(t *testing.T) { ... }
t.Run("test 1", func(t *testing.T) { ... })

// RIGHT:
func TestParse_ValidJSON(t *testing.T) { ... }
func TestParse_MalformedInput(t *testing.T) { ... }
t.Run("trailing comma", func(t *testing.T) { ... })
```

**Index-based table test identification:**

```go
// WRONG:
for i, tt := range tests {
    t.Run(fmt.Sprintf("case_%d", i), func(t *testing.T) { ... })
}
// RIGHT — always use a name field:
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) { ... })
}
```
