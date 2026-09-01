# I/O & Networking Optimization

<!-- markdownlint-disable MD013 -->

Network and I/O bottlenecks show up as goroutines blocked on syscalls or waiting for responses. The key levers are connection reuse, proper timeouts, and streaming instead of buffering.

## HTTP Transport Configuration

**Diagnose:**

1. Use goroutine and block profiles to locate waits in HTTP transport methods.
2. Use `fgprof` to compare on-CPU work with off-CPU wait time.
3. Use `go tool trace` to inspect long network waits.
4. Track `go_goroutines` under stable production load to detect growth.

### Connection pooling

The default `http.Transport` keeps two idle connections per host. This can
increase connection churn for repeated traffic to one host. It does not limit
active request concurrency to two. Use metrics and traces to identify the
actual limit. Possible limits include connection setup, a total connection cap,
and the upstream service:

```go
// Default transport can be correct for low or varied traffic
client := &http.Client{}

// Example fields only — derive each value from measurements
var apiClient = &http.Client{
    Timeout: 30 * time.Second,
    Transport: &http.Transport{
        MaxIdleConns:          100,             // total idle connections across all hosts
        MaxIdleConnsPerHost:   20,              // measured idle reuse target
        MaxConnsPerHost:       50,              // cap total connections per host (0 = unlimited)
        IdleConnTimeout:       90 * time.Second,
        TLSHandshakeTimeout:  5 * time.Second,
        ResponseHeaderTimeout: 10 * time.Second,
    },
}
```

Traffic across many hosts can retain idle connections with little reuse.
Measure reuse, connection-setup cost, file descriptors, and memory. Test
`DisableKeepAlives` only when idle-retention cost exceeds reuse value. It forces
new connections and can increase latency and CPU use:

```go
crawlerClient := &http.Client{
    Transport: &http.Transport{DisableKeepAlives: true},
}
```

### Timeouts

A zero `http.Client.Timeout` has no end-to-end deadline, although the default
transport sets some phase timeouts. Zero server timeouts leave relevant phases
unbounded. Select client, transport, server, and context deadlines from the
request contract:

```go
// Example fields only — derive each value from the service contract
server := &http.Server{
    Addr:         ":8080",
    Handler:      handler,
    ReadTimeout:  5 * time.Second,
    WriteTimeout: 10 * time.Second,
    IdleTimeout:  120 * time.Second,
}
```

### Bound response-body cleanup

Callers must close every response body. Reading to EOF can permit HTTP/1.x
connection reuse. Do not drain an untrusted body without a bound. If the bound
stops before EOF, closing the body can forfeit reuse. The following Go 1.20+
example uses `errors.Join` to retain both cleanup errors:

```go
func discardResponse(resp *http.Response, maxBytes int64) error {
    _, drainErr := io.Copy(io.Discard, io.LimitReader(resp.Body, maxBytes))
    closeErr := resp.Body.Close()
    return errors.Join(drainErr, closeErr)
}
```

Choose a positive `maxBytes` value from the response contract and resource
budget.

## Streaming vs Buffering

**Diagnose:** Use an `inuse_space` profile to find large allocations from
`io.ReadAll`, `bytes.Buffer.Grow`, or `json.Unmarshal`.

### Avoid io.ReadAll for large payloads

`io.ReadAll` grows memory with the input. For line-oriented input, set an
explicit record limit and check the terminal scanner error:

```go
scanner := bufio.NewScanner(f)
scanner.Buffer(nil, maxLineBytes)
for scanner.Scan() {
    if err := processLine(scanner.Bytes()); err != nil { return err }
}
if err := scanner.Err(); err != nil { return err }
```

`Scanner.Bytes` aliases scanner storage. Copy it if processing retains the data.
Pass a validated, positive `maxLineBytes` limit. Use `bufio.Reader` when records
can exceed a practical scanner bound. Use `io.ReadAll` only when a verified
input bound fits the memory budget.

### Streaming JSON

For a large top-level JSON array, decode each element if processing must use
bounded memory. Calling `Decode(&slice)` still constructs the full slice:

```go
dec := json.NewDecoder(r)
tok, err := dec.Token()
if err != nil { return err }
if tok != json.Delim('[') { return errors.New("expected JSON array") }
for dec.More() {
    var item Item
    if err := dec.Decode(&item); err != nil { return err }
    if err := process(item); err != nil { return err }
}
tok, err = dec.Token()
if err != nil { return err }
if tok != json.Delim(']') { return errors.New("expected end of JSON array") }
```

## JSON Performance

**Diagnose:** Use a CPU profile to confirm that JSON encoding or reflection is
material. Compare representative payloads with `go test -bench -benchmem`.

The standard `encoding/json` package can use reflection to inspect struct
fields. Consider alternatives only when profiles show material CPU or
allocation cost.

**Options for faster JSON:**

- **Custom `MarshalJSON`/`UnmarshalJSON`** — methods for hot-path types can avoid
  generic reflection
- **Code generation** — assess a maintained generator against the target Go
  version, data model, and representative payloads
- **Alternative implementations** — compare compatibility and performance of
  maintained candidates against representative payloads
- **`encoding/json/v2`** (experimental, behind `GOEXPERIMENT=jsonv2`) —
  evaluate deliberately. Keep `encoding/json` unless the project opts into the
  experiment

When using third-party JSON libraries, refer to the library's official documentation for up-to-date API signatures.

## Cgo Overhead

**Diagnose:** Use CPU and thread profiles to locate cgo transition cost.
Benchmark the actual call loop against a viable alternative.

Each Go-to-C call has transition and scheduler costs. Measure them on the target
toolchain and platform:

```go
// Per-element cgo transitions
for i, v := range values {
    values[i] = float64(C.sqrt(C.double(v)))
}

// Pure Go candidate when its semantics match the requirement
for i, v := range values { values[i] = math.Sqrt(v) }
```

If C is required, assess batching across the boundary. Validate empty inputs,
length conversion, pointer lifetime, and cancellation before adding a batch
call.

## Buffered I/O

**Diagnose:**

1. Benchmark buffered and unbuffered I/O with `go test -bench`.
2. Use `go tool trace` to find frequent short syscalls such as `pread` and
   `pwrite`.

Small unbuffered operations can issue many syscalls. A buffered writer can
combine them. Check every write and flush error:

```go
w := bufio.NewWriter(f)
for _, line := range lines {
    if _, err := w.WriteString(line + "\n"); err != nil { return err }
}
if err := w.Flush(); err != nil { return err }
```

## Concurrent Multi-Stage Pipelines

**Diagnose:**

1. Use `go tool trace` to find idle gaps between pipeline stages.
2. Use CPU and goroutine profiles to verify that stages use different
   resources.

Concurrent stages can improve throughput when each stage saturates a different
resource. Examples include CPU, disk I/O, and network capacity.

### Pipeline contract

A production pipeline must propagate cancellation and the first stage error.
Each producer owns closure of its output channel. Bound all queues and worker
counts. Handle every I/O error, and close every HTTP response body. Test startup,
partial failure, cancellation, and shutdown without blocked goroutines.

### When to use a pipeline

**Use concurrent pipelines only when ALL of these are true:**

1. **Resource saturation is predictable and separate.** Measurements show that
   A, B, and C saturate different resources.
2. **Bottleneck shifts do not harm latency.** Processing order is irrelevant,
   or records can flow through stages out of order.
3. **Buffering overhead is acceptable.** Inter-stage channels consume memory.
   Large records can make channel buffers exceed system limits.
4. **A benchmark covers both designs.** Profile sequential and concurrent
   versions. Sequential batching can win because it avoids context switches.

**Avoid concurrent pipelines if:**

- **Records must stay ordered.** Concurrent processing can reorder records.
  Restoring order can remove the gain.
- **Resources overlap.** Competing CPU stages add context switches without more
  resource capacity.
- **Latency matters more than throughput.** Pipeline queues can increase the
  latency of one record.
- **Memory is tight.** Each channel buffer consumes a memory budget. Deep
  buffers can exhaust available RAM.

Define channel ownership, cancellation, bounds, and shutdown
before adding pipeline concurrency.
Validate worker counts against the measured resource bottleneck.

## Batch Operations

**Diagnose:**

1. Benchmark single-item and batched operations with `go test -bench`.
2. Use `go tool trace` to find short operations with idle gaps between them.

Batching can amortize syscall, protocol, and transaction overhead. Compare it
with the single-item path under representative load.

### Database: batch inserts over row-by-row

Compare row statements with the driver's supported bulk API. Protocol and
transaction behavior determine how much work a batch removes. Choose batch
size from server limits and workload measurements. Handle begin, prepare,
execute, close, rollback, and commit errors.

### HTTP: batch API calls

Use an HTTP batch endpoint only when its item-level semantics match the
individual operation. Bound request and response sizes. Propagate context,
check status and item errors, and close the response body.

### Channel: batch processing from a stream

Flush on a measured item or byte limit and a bounded deadline. Accept
cancellation, return flush errors, stop timers, and define ownership of each
item. Do not reuse batch storage while a consumer can retain it.
