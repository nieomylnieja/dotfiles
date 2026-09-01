# Memory Optimization

<!-- markdownlint-disable MD013 -->

Use allocation and heap profiles to determine whether allocation rate or
retained memory is a material cost. Allocation reduction can reduce garbage
collector work, but it is not the highest-value change for every program.

Use the repository-supported pprof frontend. Check that its executable or task
is available before profile inspection. Do not assume that `go tool pprof`
exists. If no supported frontend is available, report the missing tool and stop
the profile analysis.

## Allocation Patterns

**Diagnose:**

1. Use the verified pprof frontend to rank allocation sites by object count.
2. Use `go build -gcflags="-m -m"` to inspect escape decisions.
3. Use `go test -bench -benchmem` to measure allocations and bytes per
   operation.

### Reuse slices with `append(s[:0], ...)`

Reslicing to zero length can reuse the backing array when it has enough
capacity. It also retains that array, so do not use it when retention is the
problem.

```go
// Bad — allocates new slice, old one becomes garbage
mode = []T{item}

// Can reuse the existing backing array
mode = append(mode[:0], item)
```

### Direct indexing vs append

When the output size equals the input size, indexed assignment expresses the
result length directly. Both forms can allocate one backing array, and compiler
optimizations can remove much of their loop overhead. Benchmark only when this
loop is measured as hot:

```go
// Useful when result length can vary
result := make([]T, 0, len(input))
for i := range input { result = append(result, transform(input[i])) }

// Clear when result length is fixed
result := make([]T, len(input))
for i := range input { result[i] = transform(input[i]) }
```

Use append when the result might be smaller (filtering) or when early error return could discard partial results.

### Eliminate redundant map lookups

`for k := range m { use(m[k]) }` performs an additional lookup for each key.
Capture the value from `range`:

```go
// Additional lookup for each key
for k := range in { result[k] = fn(in[k]) }

// Good — single lookup
for k, v := range in { result[k] = fn(v) }
```

### Map size hints

`make(map[K]V, n)` gives an initial capacity hint. It can reduce growth work,
but it does not guarantee one allocation or no growth:

```go
m := make(map[string]int, len(items))
```

### Sentinel errors vs fmt.Errorf

A sentinel can preserve stable error identity and can avoid repeated error
construction. Use one when the API contract calls for it, not only from an
unverified allocation assumption:

```go
var ErrNegative = errors.New("value is negative") // allocated once

func validate(x int) error {
    if x < 0 { return ErrNegative }
    return nil
}
```

Use `fmt.Errorf` for dynamic context or `%w` wrapping. Preserve error identity
when callers use `errors.Is` or `errors.As`.

### Interface values

An interface value stores type and value information. Conversion does not
always force a heap allocation. Escape behavior depends on the concrete value,
compiler, and use. If profiles attribute allocation or dispatch cost to an
interface-heavy path, compare a typed or generic API:

```go
// Dynamic representation
func sum(values []any) int { ... }

// Typed representation
func sum(values []int) int { ... }

// Generic representation
func sum[T ~int | ~int64](values []T) T { ... }
```

## Backing Array Leaks

**Diagnose:**

1. Inspect live-space data with the verified pprof frontend.
2. Compare allocated-space data with final retained data.

### Slice reslicing can retain a backing array

A small reslice can keep a large original array reachable. Check the input
length before slicing, and copy when the result must not retain the input:

```go
func getHeader(data []byte) ([]byte, bool) {
    if len(data) < 16 {
        return nil, false
    }
    return append([]byte(nil), data[:16]...), true
}
```

### Substring retention

A substring can keep the original string data reachable. Check byte-length
requirements before slicing:

```go
func extractID(msg string) (string, bool) {
    if len(msg) < 8 {
        return "", false
    }
    return strings.Clone(msg[:8]), true
}
```

### Map capacity retention

Deleting entries does not guarantee that a map returns its allocated storage.
If a heap profile shows material retained capacity after a high-water mark,
compare rebuilding the map with keeping it:

```go
func compact(old map[string]Data) map[string]Data {
    m := make(map[string]Data, len(old))
    for k, v := range old { m[k] = v }
    return m // old map becomes eligible for GC
}
```

## String and Byte Optimization

**Diagnose:**

1. Use an allocation profile to find hot string and byte conversions.
2. Use `go test -bench -benchmem` to compare measured alternatives.

**Cache measured string-to-byte conversions** — ordinary conversions usually
copy data, but the compiler can optimize some non-escaping conversions. Use
profiles and benchmarks before adding retained state.

**Use `bytes` package directly** — `bytes.Contains`, `bytes.HasPrefix`, `bytes.Split`, `bytes.ToUpper` etc. operate on `[]byte` without string conversion. The `bytes` package mirrors most of `strings`.

## sync.Pool Hot-Path Patterns

**Diagnose:** Use an allocation profile to find repeated allocation of the same
temporary object type.

`sync.Pool` can reuse temporary objects and reduce allocation pressure. The
runtime can remove pooled items at any time. Use it only for a measured,
concurrent hot path:

```go
var bufPool = sync.Pool{
    New: func() any {
        buf := make([]byte, 0, 4096)
        return &buf
    },
}

func handleRequest(data []byte, maxPooledCapacity int) []byte {
    bp := bufPool.Get().(*[]byte)
    buf := (*bp)[:0] // reset length, keep capacity
    defer func() {
        if cap(buf) <= maxPooledCapacity {
            *bp = buf[:0]
            bufPool.Put(bp)
        }
    }()

    // ... process data into buf ...

    result := make([]byte, len(buf))
    copy(result, buf) // return a copy — buf goes back to pool
    return result
}
```

**Rules:**

- Reset state before `Put()` — clear references to avoid retaining large object graphs across GC cycles
- Return copies, not pooled buffers — callers must not hold references to pooled memory
- Bound retained capacity from workload measurements. Do not return rare,
  oversized objects to a pool that would retain excessive memory.
- Do not pool infrequently used objects — pool overhead can exceed the benefit
  when allocations are rare

Review the current `sync.Pool` package documentation
and the project's concurrency guidance before introducing a pool.
A pool is a runtime optimization, not an ownership mechanism.

## Memory Layout

**Diagnose:**

1. Use `fieldalignment ./...` to identify candidates with excess padding.
2. Use `unsafe.Sizeof`, `unsafe.Alignof`, and `unsafe.Offsetof` to compare exact
   layouts.

### Struct field alignment

Go adds padding between fields to meet target-architecture alignment. Grouping
fields by alignment can reduce size. Measure the actual type because field
order also affects readability and API compatibility. It can also affect
atomic alignment:

```go
// Bad — 24 bytes (7 + 3 bytes padding)
type Bad struct {
    a bool    // 1 byte + 7 padding
    b int64   // 8 bytes
    c bool    // 1 byte + 3 padding
    d int32   // 4 bytes
}

// Good — 16 bytes (2 bytes padding)
type Good struct {
    b int64   // 8 bytes
    d int32   // 4 bytes
    a bool    // 1 byte
    c bool    // 1 byte + 2 padding
}
```

The example sizes assume a 64-bit target. Use `unsafe.Sizeof`,
`unsafe.Alignof`, and `unsafe.Offsetof` for the supported architectures.

**Inspect layout:** `unsafe.Sizeof(T{})`, `unsafe.Alignof(T{})`, `unsafe.Offsetof(T{}.field)`

### Zero-size field at end of struct

If the last field has zero size (`struct{}`), the compiler can add word-sized
padding. This prevents its address from overlapping the next memory block:

```go
// Bad — 16 bytes (8 for Value + 8 padding for Flag)
type Entry struct { Value int64; Flag struct{} }

// Good — 8 bytes (0 for Flag + 8 for Value)
type Entry struct { Flag struct{}; Value int64 }
```

A zero-size field can carry type-level meaning. Move it only when measured
layout matters and field order is not part of a compatibility contract.

### Receiver choice

Choose pointer receivers for mutation, identity, synchronization, or when
copying a measured large value is costly. The compiler can inline methods and
elide some copies, so there is no universal size threshold. Keep a type's method
set coherent.

### Map of pointers for large, frequently updated structs

Map values are not addressable — you cannot modify a field in place. For large structs with frequent updates, `map[K]*V` avoids the copy-modify-reassign pattern:

```go
players := map[string]*Player{"alice": {Score: 100}}
players["alice"].Score += 10 // direct modification, no copy
```

Trade-off: pointer values add indirection and can increase allocation count and
GC scanning. Value maps can be better for small, mostly-read structs. Measure
the real construction and update pattern.
