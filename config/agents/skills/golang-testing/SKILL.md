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

## Test Style

- Use table-driven tests with subtests (`t.Run`)
- Call `t.Helper()` in test helper functions
  so failure lines point to the call site, not the helper
- Call `t.Parallel()` at the top of tests that are independent
- Store test fixtures in a `testdata/` directory
- Be aware of build tags like `//go:build unit_test` —
  if present, include them in build and test commands

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
    tests := []struct {
        input string
        want  int
    }{
        {"42", 42},
        {"0", 0},
    }
    for _, tt := range tests {
        t.Run(tt.input, func(t *testing.T) {
            got, err := parse(tt.input)
            require.NoError(t, err) // skip remaining assertions on failure
            assert.Equal(t, tt.want, got)
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
| `assert.Equal(t, want, got)` | value comparison |
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
