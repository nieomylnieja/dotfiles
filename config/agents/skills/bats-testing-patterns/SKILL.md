---
name: bats-testing-patterns
description: >-
  Use when writing or reviewing Bats tests, shell-command tests, CLI integration
  tests, fixture-heavy suites, or Docker-backed Bats runners.
---

# Bats testing

Treat CLI output, exit status, files, and external effects as observable
behavior. Inspect the project's runner, tags, helpers, fixtures, and installed
Bats libraries before adding a pattern.

## Inspect the suite

Look for:

- project test targets and containerized runners;
- the supported Bats version;
- `setup_suite.bash`, shared helpers, and assertion libraries;
- file and test tags;
- input and expected-output fixture conventions;
- local rules for unit, integration, and end-to-end tests.

Use the project target when it sets build flags, dependencies, credentials, or
containers. Do not replace its test selection with custom environment flags.

## Choose the test boundary

- Use Bats for shell code and observable CLI workflows.
- Use the implementation language's test framework for internal functions.
- Keep unit tests deterministic and offline.
- Mark tests that need services, credentials, or mutable remote state. Run them
  only through the project's authorized integration or end-to-end path.
- Use a pseudo-terminal (PTY) only when TTY detection or terminal interaction is
  part of the behavior.

## File structure

A `.bats` file can omit a shebang. If the project uses one, use
`#!/usr/bin/env bats`, not a Bash shebang.

Keep lifecycle functions near the top, tests next, and file-local helpers at the
bottom unless the repository has another consistent order. Put reusable helpers
in the suite's helper directory.

Use the narrowest Bats-managed temporary directory:

- `$BATS_TEST_TMPDIR` for one test;
- `$BATS_FILE_TMPDIR` for one test file;
- `$BATS_SUITE_TMPDIR` for one suite.

Do not use `$BATS_TMPDIR` as suite-owned scratch space. It is the parent
directory selected by Bats and can be shared with other runs.

## Run commands safely

Pass arguments directly when shell parsing is not under test:

```bash
run_cli() {
  bats_require_minimum_version 1.5.0
  run --separate-stderr my-cli "$@"
}
```

Do not interpolate `$*` into `bash -c`. If a pipeline or redirection is the
behavior under test, pass positional parameters separately:

```bash
run_pipeline() {
  bats_require_minimum_version 1.5.0
  run --separate-stderr bash -o pipefail -c \
    'my-cli "$1" | sed "s/[[:space:]]*$//"' bash "$1"
}
```

Use `bash -c` only when the suite intentionally tests Bash syntax. Match the
shell to the command's documented environment.

## Setup and isolation

Use:

- `setup_suite` for immutable suite dependencies and suite-level resources;
- `setup_file` for file-level state;
- `setup` for per-test state;
- the matching teardown level for cleanup.

Do not modify a source fixture in place. Copy it into a Bats temporary directory
before passing it to an editor, formatter, migration, or command that can write.

```bash
@test "edit persists the requested change" {
  local working_file="${BATS_TEST_TMPDIR}/resource.yaml"
  cp -- "${FIXTURES}/resource.yaml" "${working_file}"

  EDITOR="${TEST_HELPERS}/editor-add-label" run_cli edit "${working_file}"

  assert_success
  assert_file_equal "${working_file}" "${EXPECTED}/resource-edited.yaml"
}
```

Generate unique names for mutable external resources. Make cleanup idempotent
only when setup can fail after partial creation. Do not hide ordinary teardown
failures with `|| true`.

## Assertions

Use the project's assertion libraries. Check status before output or effects:

```bash
run --separate-stderr my-cli show missing
assert_failure 1
assert_output ""
assert_equal "${stderr}" "resource \"missing\" was not found"
```

Prefer an inline exact assertion for a short, stable message. Use file-backed
fixtures for long output, structured documents, repeated output, or text that
reviewers benefit from editing as a whole. Use partial matches only for values
that cannot be normalized, and state why.

Keep stdout and stderr separate for error behavior. Join them only when the
public interface intentionally combines them or when a project helper defines
that contract.

Normalize structured data before comparison:

```bash
assert_yaml_equal() {
  local have="$1"
  local want="$2"

  assert_equal \
    "$(yq --sort-keys -y . <<<"${have}")" \
    "$(yq --sort-keys -y . <<<"${want}")"
}
```

Use the repository-selected yq implementation. Python yq and mikefarah yq have
different flags and output.

## Test design

- Name tests for user-visible conditions and outcomes.
- Cover success, invalid input, dependency failure, and cleanup where relevant.
- Test aliases or flag variants in a loop only when their expected behavior is
  identical.
- Keep complete workflow tests small enough that one failure identifies the
  broken step.
- Pin terminal width, `TERM`, color mode, and locale for terminal output.
- Use local fixture servers instead of live APIs in deterministic tests.
- Do not assert implementation details that users cannot observe.

## Verify

Run the repository's Bats target and the narrow changed file or tag when the
runner supports it. Report the exact missing tool, unavailable service, or
skipped credential-dependent suite. A raw `bats` run is not equivalent when
the project wrapper builds the binary or provides dependencies.
