---
name: shell
description: >-
  Use when reading, writing, reviewing, or debugging Bash, POSIX sh, shell
  command tests, or embedded awk, jq, and yq programs.
allowed-tools: Bash(shellcheck *) Bash(shfmt *)
---

# Shell

Follow the repository's supported shell, style, and task runner. Do not apply
Bash rules to POSIX `sh`, sourced files, shell fragments, or interactive shell
configuration.

Read [sources.md](./references/sources.md) when a portability or shell-semantics
claim needs a primary source.

## Establish the contract

Before editing, determine:

- whether the file executes, is sourced, or is embedded in another format
- whether it targets Bash or POSIX `sh`
- which operating systems and shells it supports
- whether output, exit codes, and error text are public CLI behavior
- which formatter, linter, and tests the project uses.

Preserve the existing dialect. Use `#!/usr/bin/env bash` for portable Bash
entrypoints when the project permits environment lookup. Use `#!/bin/sh` only
for code that is POSIX-compatible. A Nix-generated script can use its resolved
interpreter path.

## Failure behavior

Use `set -euo pipefail` for a new Bash entrypoint when its control flow is
compatible with those options. Do not add it mechanically to sourced files,
wrappers that handle nonzero statuses, or POSIX code that does not support
`pipefail`.

Remember these `errexit` limits:

- conditions in `if`, `while`, `until`, `!`, and most `&&` or `||` lists do not
  behave like ordinary failing commands
- pipeline status needs `pipefail` in Bash
- a declaration such as `local value="$(command)"` can hide command failure
- `((count++))` returns a failing status when its prior value is zero.

Handle expected failures explicitly. Send diagnostics to stderr. Use a helper
whose status is separate from its message:

```bash
fatal() {
  local message="$1"
  local status="${2:-1}"
  printf '%s: ERROR: %s\n' "${PROG}" "${message}" >&2
  exit "${status}"
}
```

Do not discard stderr or append `|| true` unless failure is deliberately
optional. If it is optional, preserve enough context to diagnose it.

## Structure and arguments

Use a `main` function for a nontrivial executable when it improves control
flow. Do not add `main`, `--help`, or a GNU-style interface to a sourced helper
or small internal fragment that has no CLI contract.

For a public CLI:

- preserve the project's existing help format and exit-code policy
- write help to stdout and exit zero
- reject unknown options and missing option values
- support `--` when positional arguments can start with `-`
- use exit status 2 for usage errors only when the project follows that
  convention.

Use arrays for Bash argument lists and `"$@"` for forwarding. Never construct a
command in a string or use `eval`. Quote expansions unless intentional word
splitting or globbing is part of a documented contract.

## Temporary files and cleanup

Use `mktemp` or the project's test-framework directory. Do not use predictable
paths in shared temporary directories. Validate a destructive target before
removing it.

Install cleanup traps only for resources the current process owns. An `EXIT`
trap runs on normal exit and many failures, but it does not run after `SIGKILL`
or every external termination. Preserve an existing status when cleanup must
not replace it.

## Embedded programs

Keep nontrivial awk, jq, and yq programs readable. Prefer a quoted heredoc
delimiter so the shell cannot expand `$`, backticks, or command substitutions:

```bash
jq --arg name "${name}" "$(
  cat <<'JQ'
.items
| map(select(.name == $name))
JQ
)" "${input_file}"
```

Pass data through `jq --arg` or `--argjson`, `awk -v`, and the selected yq
implementation. Do not interpolate untrusted text into program source. Use an
unquoted heredoc only when shell expansion is intentional and every expansion
is controlled.

## Security and portability

- Keep the caller's `PATH` on NixOS and other non-FHS systems. For privileged
  scripts, build a restricted `PATH` from resolved package paths instead of
  assuming `/usr/bin:/bin` exists.
- Put `--` before untrusted positional operands when the command supports it.
- Validate paths, numbers, URLs, and enum-like inputs at the boundary.
- Set `umask 077` before creating secret-bearing files.
- Do not log credentials or secret-bearing command lines.
- Use `command -v` instead of `which`.

## Verify

Use project commands first. Otherwise, for changed executable shell files:

```sh
shfmt -d path/to/file.sh
shellcheck path/to/file.sh
```

Also run the narrow behavior test that proves the changed success and failure
paths. Use [bats-testing-patterns](../bats-testing-patterns/SKILL.md) when the
project uses Bats or the task changes observable CLI behavior.
