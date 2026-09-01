---
name: golang-comments
description: >-
  Use when writing, editing, reviewing, or deciding whether to add Go doc
  comments, package comments, declaration comments, or Go comment directives.
---

# Go comments

Load [code-comments](../code-comments/SKILL.md) for content decisions. Use this
skill for Go syntax and rendering. Follow the owning module's Go version and
the repository's documentation policy.

Reference: [Go doc comment syntax](https://go.dev/doc/comment).

## Declaration comments

Put a doc comment directly before the declaration. Start with the declared name
when that produces a clear sentence:

```go
// Parse returns the configuration represented by data.
func Parse(data []byte) (Config, error)
```

Go tools conventionally expect comments for exported declarations, but not
every project enforces that rule. Follow project lint policy. A required comment
must still describe a useful contract instead of restating the identifier.

Document relevant:

- zero-value behavior;
- concurrency safety;
- ownership and mutation;
- error identity and partial results;
- side effects and cancellation;
- accepted formats, ranges, and special values.

Use “reports whether” for a boolean when it reads naturally. Do not force a
stock sentence form when it makes the contract less precise.

Only one file needs the package comment. Start it with `Package name` and
describe the package's purpose, not its directory.

Use the exact prefix `Deprecated:` for deprecation notices and state the
replacement or migration path.

## Doc links

Use Go doc links for symbols:

- `[Buffer]` and `[Buffer.Reset]` for the current package;
- `[io.Reader]` for an imported package;
- `[encoding/json.Decoder]` when a full path avoids ambiguity.

Use backticks for non-symbol literals such as `nil`, file names, flags, and
commands. Do not convert ordinary parameter names into links.

Define a prose link target at the end of a doc comment:

```go
// Package wire implements the format defined by [Protocol X].
//
// [Protocol X]: https://example.com/protocol
package wire
```

## Blocks and directives

Blank comment lines separate paragraphs. Go 1.19+ recognizes unindented
`# Heading` lines. Use headings and lists only when a short paragraph is not
clearer.

Indent list items and code according to `gofmt` and Go doc syntax. Check the
rendered result when a comment contains nested structure.

Tool directives such as `//go:generate`, `//go:build`, and
`//nolint:<name>` are not prose. Keep their required position and syntax.
Give a narrow reason for a lint suppression when the tool permits it.

## Verify

Run `gofmt` through the project's formatter. Run the configured doc-comment
linter and `go test` for executable examples. Use `go doc` or the project
documentation renderer when links, headings, lists, or code blocks changed.

Check that the comment describes the current declaration and does not duplicate
generated API or schema metadata.
