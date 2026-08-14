# Go Library Selection

These are starting points, not mandatory dependencies. Prefer the standard
library when it meets the contract, and preserve a repository's established
library unless a migration has a concrete benefit.

The time-sensitive module paths and maintenance notes were reviewed on
2026-08-14. Verify them again before adding a dependency.

Before adding or upgrading a module:

- confirm compatibility with the project's Go version and platforms;
- inspect the latest stable release, changelog, maintenance activity, and known
  security issues;
- review the license and transitive dependency cost;
- pin the selected version through `go.mod`; and
- run the repository's tests and module checks.

Do not equate "latest" with "correct." A new major version can require a newer
Go version or contain intentional breaking changes.

## HTTP

Use `net/http` directly for ordinary clients and servers. Since Go 1.22,
`http.ServeMux` supports method-aware patterns and path wildcards, so many
services do not need an external router.

Choose an external router or framework only for requirements the standard
library does not meet. Account for middleware behavior, route precedence,
encoded paths, observability integration, and migration cost.

## CLI

Use `flag` for small CLIs whose parsing and help requirements are simple.

For subcommands and richer flag behavior, consider
[`github.com/urfave/cli/v3`](https://github.com/urfave/cli). The project
recommends v3 for new development; v2 receives security and bug fixes but is not
the preferred major version for new applications.

For interactive terminal applications, select only the required Charm modules:

- [`charm.land/huh/v2`](https://github.com/charmbracelet/huh) for
  forms and prompts;
- [`charm.land/bubbletea/v2`](https://github.com/charmbracelet/bubbletea)
  for a stateful terminal UI; and
- [`charm.land/lipgloss/v2`](https://github.com/charmbracelet/lipgloss)
  for terminal styling and layout.

Do not add a full TUI framework for a non-interactive command.

## Logging

Use `log/slog` on Go 1.21+ when its handler model meets the requirements. Keep
an existing logging abstraction when replacing it would change fields,
sampling, context propagation, or backend integration without a clear benefit.

## Configuration

For a small number of variables, `os.LookupEnv`, `flag`, and explicit parsing
can be clearer than reflection and struct tags.

For struct-based environment parsing, consider
[`github.com/caarlos0/env/v11`](https://github.com/caarlos0/env). It parses the
process environment; it does not load `.env` files. Check its required Go
version before adoption.

Existing projects that use
[`github.com/kelseyhightower/envconfig`](https://github.com/kelseyhightower/envconfig)
do not need to migrate solely because another option exists. Compare supported
tags, error behavior, maintenance, and compatibility before changing libraries.

## Database

Start with `database/sql` when its driver abstraction fits. For PostgreSQL,
consider:

- [`github.com/jackc/pgx/v5`](https://github.com/jackc/pgx) for a PostgreSQL driver
  and PostgreSQL-specific capabilities; and
- [`github.com/sqlc-dev/sqlc`](https://github.com/sqlc-dev/sqlc) to generate
  typed Go code from SQL. It is a build tool, not a runtime ORM.

Do not reject all ORMs categorically. Choose between SQL, a query builder,
generated queries, and an ORM from the application's query complexity,
transaction model, schema ownership, performance needs, and team experience.
An ORM's hidden queries and impedance mismatch are costs to evaluate, not proof
that every ORM use is wrong.

## Testing

Use the standard `testing` package and repository-local helpers first.

Consider [`github.com/stretchr/testify`](https://github.com/stretchr/testify)
when the project already uses it or its assertions and mocks materially improve
the suite. Do not add it for one trivial comparison. Follow
[golang-testing](../../golang-testing/SKILL.md) for test design and failure
semantics.

## Serialization

- Use `encoding/json` for stable standard JSON behavior. `encoding/json/v2`
  remains experimental through Go 1.26 and requires
  `GOEXPERIMENT=jsonv2`.
- Consider [`github.com/goccy/go-yaml`](https://github.com/goccy/go-yaml) for
  YAML when its compatibility, AST, and error behavior fit.
- Consider [`github.com/BurntSushi/toml`](https://github.com/BurntSushi/toml)
  for TOML.
- Use [`google.golang.org/protobuf`](https://pkg.go.dev/google.golang.org/protobuf)
  for Protocol Buffers.

Serialization libraries differ in duplicate-key handling, unknown fields,
numeric precision, tags, comments, anchors, and security limits. Test the input
contract instead of treating formats or implementations as interchangeable.

## Go Source Analysis

Use `go/parser`, `go/ast`, and `go/token` for syntax-only work on known files.

Use
[`golang.org/x/tools/go/packages`](https://pkg.go.dev/golang.org/x/tools/go/packages)
when analysis needs build tags, module-aware package loading, imports, or type
information. `go/parser.ParseDir` remains usable for limited syntax tasks, but
it is deprecated for precise package membership because it does not account for
build tags.

Use
[`golang.org/x/tools/go/ast/astutil`](https://pkg.go.dev/golang.org/x/tools/go/ast/astutil)
for cursor-based traversal, AST rewriting, path lookup, and import management.

Request only the `packages.LoadMode` data the analysis needs; type and
dependency loading can be expensive.

## Validation

Consider [`github.com/nobl9/govy`](https://github.com/nobl9/govy) for
reflection-free, typed validation when its rule and error model fit the API.
For a small invariant, direct code can be clearer than a framework dependency.

## Concurrency Utilities

Use [`golang.org/x/sync`](https://pkg.go.dev/golang.org/x/sync) for focused
primitives such as `errgroup`, `singleflight`, and `semaphore`.

Prefer `errgroup` only when sibling tasks return errors and first-error
reporting, optionally with fail-fast cancellation, matches the operation. A
`sync.WaitGroup` is appropriate when tasks do not return errors or manage them
independently.
