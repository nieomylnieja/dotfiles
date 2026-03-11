---
name: golang-comments
description: >
  Use this skill when writing or editing Go doc comments.
  Covers doc comment style, doc links ([pkg.Name] syntax),
  headings, lists, code blocks, and common formatting mistakes.
---

# Go Doc Comments

Go doc comments appear immediately before top-level `package`, `const`,
`func`, `type`, and `var` declarations with no intervening blank lines.
Every exported (capitalised) name must have a doc comment.

Reference: [go.dev/doc/comment](https://go.dev/doc/comment)

---

## Doc Links — Most Important Rule

**Use `[Name]` doc links to refer to Go symbols, not backtick code fences.**

```go
// WRONG — backtick does not create a navigable link:
// Use `fmt.Errorf` to wrap errors.

// RIGHT — creates a hyperlink in pkg.go.dev and gopls hover:
// Use [fmt.Errorf] to wrap errors.
```

Doc link forms:

| Reference | Syntax |
| --- | --- |
| Same-package symbol | `[Buffer]`, `[Buffer.Reset]` |
| Pointer type | `[*Buffer]` |
| Other package (short name) | `[fmt.Errorf]`, `[io.Reader]` |
| Other package (full path) | `[encoding/json.Decoder]` |
| Package itself | `[encoding/json]`, `[path/filepath]` |

Use a full import path only when the short name is ambiguous.
Doc links must be surrounded by punctuation, spaces, tabs,
or start/end of line — they do not trigger inside `map[K]V` or generics.

Use backticks **only** for:

- Inline shell commands or non-Go literals (`` `go test ./...` ``)
- Values that are not Go identifiers (`` `nil` ``, `` `true` ``)
- Parameter names referred to by their literal text

---

## Comment Style by Declaration Kind

### Package

Begin with "Package name …" as the first sentence.
For large packages, give a brief API overview with doc links.

```go
// Package path implements utility routines for manipulating
// slash-separated paths.
//
// The path package should only be used for paths separated by forward
// slashes, such as paths in URLs.
// To manipulate operating system paths, use the [path/filepath] package.
package path
```

Only one source file in a multi-file package should have a package comment.

### Type

Explain what each instance represents or provides.
Document zero-value semantics and concurrency guarantees.

```go
// A Buffer is a variable-sized buffer of bytes with [Buffer.Read]
// and [Buffer.Write] methods.
// The zero value for Buffer is an empty buffer ready to use.
type Buffer struct { ... }

// Regexp is the representation of a compiled regular expression.
// A Regexp is safe for concurrent use by multiple goroutines,
// except for configuration methods such as [Regexp.Longest].
type Regexp struct { ... }
```

### Func / Method

Say what the function **returns** (or does, for side-effect functions).
Use "reports whether" for boolean-returning functions.
Name parameters directly in prose — no special syntax needed.

```go
// Quote returns a double-quoted Go string literal representing s.
func Quote(s string) string

// HasPrefix reports whether s begins with prefix.
func HasPrefix(s, prefix string) bool

// Copy copies from src to dst until EOF or an error occurs.
// It returns the total bytes written and the first error encountered,
// if any.
//
// A successful Copy returns err == nil, not err == [io.EOF].
func Copy(dst Writer, src Reader) (n int64, err error)
```

Do not explain internal implementation details in doc comments;
keep those in body comments.

### Const / Var

A single doc comment can introduce a group; individual members use
end-of-line comments.

```go
// Generic file system errors tested with [errors.Is].
var (
    ErrInvalid    = errInvalid()    // "invalid argument"
    ErrPermission = errPermission() // "permission denied"
    ErrNotExist   = errNotExist()   // "file does not exist"
)
```

---

## Syntax Rules

### Paragraphs

Unindented, non-blank lines form a paragraph.
Blank lines separate paragraphs.
Use semantic line breaks (one sentence or clause per source line).

### Headings

A line starting with `#` (hash + space) is a heading,
provided it is unindented and surrounded by blank lines.

```go
// # Numeric Conversions
//
// The most common conversions are [Atoi] and [Itoa].
```

Only available in Go 1.19+.
Headings must be a single line; multi-line `#` prefixes are not headings.

### Links

Define link targets at the end of the comment as `[Text]: URL`.
Use them inline as `[Text]`.

```go
// Package json implements encoding and decoding of JSON as defined in
// [RFC 7159].
//
// [RFC 7159]: https://tools.ietf.org/html/rfc7159
package json
```

Plain URLs in prose are auto-linked in HTML renderings.

### Lists

Indent list items with spaces/tabs.
Use `-`, `*`, `+`, or `•` for bullet items;
a decimal followed by `.` or `)` for numbered items.

```go
// PublicSuffixList provides the public suffix of a domain. For example:
//   - the public suffix of "example.com" is "com",
//   - the public suffix of "foo1.foo2.foo3.co.uk" is "co.uk".
```

Nested lists are not supported — flatten them.

### Code Blocks

Any indented (non-list) span is a code block rendered in fixed-width font.
Always separate code blocks from surrounding prose with a blank `//` line.

```go
// Search uses binary search to find the smallest index i such that f(i).
//
//  func GuessingGame() {
//      answer := sort.Search(100, func(i int) bool { ... })
//  }
func Search(n int, f func(int) bool) int
```

### Notes and Deprecations

```go
// TODO(username): refactor to use [context.Context].

// Deprecated: RC4 is cryptographically broken.
// Use [crypto/aes] instead.
package rc4
```

---

## Common Mistakes

### Accidental code blocks

Any indented line becomes a code block, even if unintentional.
Numbered lists not indented look like paragraphs + code blocks:

```go
// WRONG — "2) On Read failure…" becomes a code block:
// 1) On Read error or close, stop func is called.
// 2) On Read failure, error is wrapped as net.Error.

// RIGHT:
//  1. On Read error or close, stop func is called.
//  2. On Read failure, error is wrapped as [net.Error].
```

### Wrapped continuation lines

A wrapped continuation that is not indented enough breaks out of
the list or code block:

```go
// WRONG:
//   - Partial errors. If a service needs to return partial errors to the
// client, it may embed Status in the response.

// RIGHT:
//   - Partial errors. If a service needs to return partial errors to the
//     client, it may embed [Status] in the response.
```

### Directives

`//go:generate`, `//nolint:`, and similar tool directives are not
part of the doc comment.
Gofmt moves them after a blank line at the end of the comment.

```go
// An Op is a single regular expression operator.
//
//go:generate stringer -type Op -trimprefix Op
type Op uint8
```
