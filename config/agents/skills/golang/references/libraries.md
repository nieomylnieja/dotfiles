# Preferred Go Libraries

Prefer these libraries when they fit the task.
Do not add a dependency just to use one of these;
use the standard library if it already covers the need.

**Critical:** Always use the latest versions of these libraries,
scan for available versions first, before assuming a given version is indeed latest.

## HTTP

Use the **standard library `net/http`** directly.
Since Go 1.22, `http.ServeMux` supports method and wildcard pattern matching:

```go
mux := http.NewServeMux()
mux.HandleFunc("GET /users/{id}", handleUser)
mux.HandleFunc("POST /users", createUser)
```

No external router needed for most services.

## CLI

For simple CLIs with no subcommands, use `flag` from the standard library.
For CLIs with subcommands or complex flag handling:

- **[github.com/urfave/cli](https://github.com/urfave/cli)** —
  composable CLI framework with subcommand support

For interactive/TUI CLIs, use the [Charm](https://charm.sh) ecosystem:

- **[github.com/charmbracelet/huh](https://github.com/charmbracelet/huh)** —
  interactive forms and prompts (input, select, confirm, etc.)
- **[github.com/charmbracelet/bubbletea](https://github.com/charmbracelet/bubbletea)** —
  full TUI framework based on the Elm architecture
- **[github.com/charmbracelet/lipgloss](https://github.com/charmbracelet/lipgloss)** —
  style and layout for terminal output

## Logging

- **`log/slog`** *(stdlib, Go 1.21+)* —
  structured logging; no external package needed

## Configuration

- **[github.com/kelseyhightower/envconfig](https://github.com/kelseyhightower/envconfig)** —
  populate structs from environment variables

## Database

Do not use ORMs. They're evil!

- **[github.com/sqlc-dev/sqlc](https://github.com/sqlc-dev/sqlc)** —
  generate type-safe Go from SQL queries (code generator, not a runtime dep)
- **[github.com/jackc/pgx](https://github.com/jackc/pgx)** —
  PostgreSQL driver (used as the runtime backend for sqlc output)

## Testing

- **[github.com/stretchr/testify](https://github.com/stretchr/testify)** —
  `assert`/`require` assertions and mocks
  (see [golang-testing](../../golang-testing/SKILL.md) for assert vs require guidance)

## Serialisation

- **`encoding/json`** *(stdlib)* — default for JSON
- **[github.com/goccy/go-yaml](https://github.com/goccy/go-yaml)** — for YAML
- **[github.com/BurntSushi/toml](https://github.com/BurntSushi/toml)** — for TOML
- **[google.golang.org/protobuf](https://pkg.go.dev/google.golang.org/protobuf)** — for Protobuf

## Go AST / Source Analysis

For tools that parse, inspect, or transform Go source code.

- **[golang.org/x/tools/go/packages](https://pkg.go.dev/golang.org/x/tools/go/packages)** —
  load packages with full type information and module support.
  Replaces the `go/parser.ParseDir` + `go/token.NewFileSet()` pattern,
  which is not module-aware and does not resolve imports correctly.
  Use `packages.Load` with a `packages.Config` instead:

  ```go
  cfg := &packages.Config{
      Mode: packages.NeedName | packages.NeedFiles | packages.NeedSyntax,
  }
  pkgs, err := packages.Load(cfg, "./...")
  ```

- **[golang.org/x/tools/go/ast/astutil](https://pkg.go.dev/golang.org/x/tools/go/ast/astutil)** —
  utilities for traversing and rewriting Go ASTs
  (cursor-based `Apply`, path-finding, import management).

`go/ast`, `go/parser`, and `go/token` from the standard library
are still used directly for single-file parsing and AST node work.

## Validation

- **[github.com/nobl9/govy](https://github.com/nobl9/govy)** —
  declarative, type-safe struct validation

## Utilities

- **[golang.org/x/sync](https://pkg.go.dev/golang.org/x/sync)** —
  `errgroup`, `singleflight`, `semaphore`
  (prefer `errgroup` over manual `sync.WaitGroup` + channel error passing)
