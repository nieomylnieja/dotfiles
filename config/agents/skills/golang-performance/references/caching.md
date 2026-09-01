# Caching Patterns

<!-- markdownlint-disable MD013 -->

The fastest code is code that does not run. Cached results, deduplicated
requests, and avoided work can yield the largest gains.

## Compiled Pattern Caching

**Diagnose:**

1. Use a CPU profile to find `regexp.Compile`, `regexp.MustCompile`, or
   `template.Parse` in hot paths.
2. Compare per-call compilation with a cached version through
   `go test -bench -benchmem`.

### Regexp at package level

Compilation parses a pattern into a state machine. If a profile shows repeated
compilation, compare package-level compilation with the current path:

```go
// Bad — compiled on every call
func isValid(email string) bool {
    re := regexp.MustCompile(`^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$`)
    return re.MatchString(email)
}

// Good — compiled once, safe for concurrent use
var emailRegex = regexp.MustCompile(`^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$`)

func isValid(email string) bool { return emailRegex.MatchString(email) }
```

`regexp.MustCompile` panics on an invalid package-level constant at startup.
Use `regexp.Compile` for patterns from users. Go regexp matching takes linear
time and does not backtrack.

### Template caching

Parsing a template on each request repeats work. For a static template, parse
once during startup:

```go
var reportTmpl = template.Must(template.ParseFiles("templates/report.html"))
```

### Precomputed lookup tables

For a pure computation with a small input space, compare calculation with an
array lookup:

```go
var hexDigit = [16]byte{'0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'}

func byteToHex(b byte) (byte, byte) {
    return hexDigit[b>>4], hexDigit[b&0x0f] // two array lookups vs branching logic
}
```

A lookup can avoid repeated computation, but table size and access patterns can
offset that gain. Benchmark the target workload.

## Request-Level Caching

**Diagnose:**

1. Use a goroutine profile to find many callers blocked on one external call.
2. Use `fgprof` to identify duplicate calls that dominate wall-clock time.
3. Use an allocation profile to measure the cost of cache-miss handling.

### singleflight for cache stampede prevention

When a cache entry expires, many goroutines can request the same computation.
`singleflight` lets one goroutine fetch while the other goroutines wait:

```go
import "golang.org/x/sync/singleflight"

var (
    cache sync.Map
    sf    singleflight.Group
)

func GetWeather(city string) (string, error) {
    if val, ok := cache.Load(city); ok {
        return val.(string), nil
    }

    // Only one goroutine fetches; others block on the same key
    result, err, _ := sf.Do(city, func() (any, error) {
        data, err := fetchFromAPI(city)
        if err == nil { cache.Store(city, data) }
        return data, err
    })
    return result.(string), err
}
```

Choose cache storage independently:
use `sync.Map` or a mutex-protected map
based on the access pattern and benchmark evidence.
Layer `singleflight.Group` over either storage strategy
when concurrent duplicate misses are a measured problem.
Do not replace it solely to avoid interface boxing.
First verify that result handling is a measured bottleneck.

### LRU caches

The standard library's `container/list` supports bounded caches with eviction.
Each node uses a separate heap allocation, which can reduce cache locality.
For an LRU cache, assess these libraries:

- **`github.com/hashicorp/golang-lru`** — thread-safe, simple API
- **`github.com/elastic/go-freelru`** — uses a hash map and ring buffer. Compare
  it with the current implementation under the project's workload

When using third-party cache libraries, refer to the library's official documentation for current API signatures.

## Algorithmic Complexity

**Diagnose:** Use a CPU profile to locate repeated scans or nested loops. Inspect
the algorithm and benchmark several representative input sizes. Growth close to
the square of input size can support an O(n²) diagnosis. First separate
benchmark noise, cache effects, and setup work.

Before micro-optimization, check whether the algorithm is the bottleneck. As
input grows, a better growth rate can outweigh a constant-factor gain.

**Common complexity traps in Go:**

| Pattern | Complexity | Fix | Fixed complexity |
| --- | --- | --- | --- |
| `slices.Contains` in a loop | O(n·m) | Build a hash set, then look up each item | O(n+m) expected |
| Nested loops for matching | O(n·m) | Index one input or sort it for search | Depends on the chosen index |
| Repeated `append` growth | O(n) amortized | Use a measured capacity hint | O(n) amortized, fewer copies |
| Repeated string growth with `+=` | Can recopy accumulated data | Use `strings.Builder` | O(total output) amortized |
| Repeated min or max query | O(n) per query | Precompute for immutable data | O(n) build, O(1) query |
| Deduplication by prior-slice scan | O(n²) | Build a hash set while scanning | O(n) expected |

**Check complexity before constants.** A constant-factor gain can matter. A
change from O(n²) to O(n) can matter more as input grows.

## Work Avoidance

**Diagnose:**

1. Use a CPU profile to locate repeated scans or iterator chains in hot paths.
2. Benchmark a map or early-return candidate with `go test -bench`.

### Map lookups over slice scanning

`Contains(slice, element)` is O(n). A hash-map lookup takes expected constant
time. For repeated membership tests, compare a set with repeated scans:

```go
// Repeated scan — O(n*m)
for _, item := range subset {
    if !Contains(collection, item) { return false } // O(n) per check
}

// Hash set — O(n+m) expected
seen := make(map[T]struct{}, len(collection))
for _, item := range collection { seen[item] = struct{}{} }
for _, item := range subset {
    if _, ok := seen[item]; !ok { return false }
}
```

For a set, `struct{}` expresses that map values carry no state. Measure total
map memory if representation matters.

### Early returns and short-circuit loops

Return immediately when the answer is known. Finding the target on iteration 3 of 1000 saves 997 iterations:

```go
// Bad — always iterates full collection
found := false
for _, item := range collection {
    if item == target { found = true }
}
return found

// Good — returns on first match
for i := range collection {
    if collection[i] == target { return true }
}
return false
```

### Avoid iterator chains

Iterator chains can add helper calls and closures. If a profile identifies that
overhead, compare the chain with a direct loop:

```go
// Bad — creates 2 iterators with closures
result, ok := First(Filter(collection, predicate))

// Candidate — single pass with early return
for i := range collection {
    if predicate(collection[i]) { return collection[i], true }
}
```

### Replace indirect function calls with direct loops

A helper and closure can inhibit inlining or add calls. Confirm compiler output,
then benchmark a direct loop:

```go
// Current helper and closure
func FromSlicePtr(items []*T) []T {
    return Map(items, func(p *T) T { return *p })
}

// Direct-loop candidate
func FromSlicePtr(items []*T) []T {
    result := make([]T, len(items))
    for i := range items { result[i] = *items[i] }
    return result
}
```
