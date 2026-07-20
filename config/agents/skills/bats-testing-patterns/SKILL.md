---
name: bats-testing-patterns
description: |
  Master Bash Automated Testing System (Bats) for production shell and CLI
  testing. Use this skill whenever writing or reviewing Bats tests, shell
  command tests, CLI integration tests, fixture-heavy tests, Docker-backed Bats
  suites, or unit/e2e test split patterns for shell utilities.
---

# Bats Testing Patterns

Use this skill to build maintainable Bats test suites for shell scripts and
command-line programs.
Favor project-local conventions over generic examples:
first inspect the existing runner, helpers, fixtures, and tags, then extend
those patterns.

## When to Use This Skill

- Writing unit or e2e tests for shell scripts and CLI tools.
- Adding Bats coverage for edge cases, error messages, and output formats.
- Creating shared Bats helpers, fixtures, or Docker-backed test runners.
- Reviewing Bats suites for maintainability, isolation, and useful failures.
- Splitting tests by tags such as `unit` and `e2e`.

## First Read the Project

Before writing tests, inspect the local suite:

```sh
fd -t f '\\.(bats|bash|sh)$' test scripts
fd -t f '^(Makefile|justfile|package.json)$' .
rg -n 'file_tags|--filter-tags|setup_suite|load_lib|run_.*\\(' test scripts Makefile
```

Look specifically for:

- task-runner targets such as `make test/bats/unit` or `make test/bats/e2e`;
- Dockerfiles or containers used to pin the Bats runtime and dependencies;
- `test/setup_suite.bash` for global suite setup;
- `test/test_helper/load.bash` or equivalent shared helper files;
- fixture roots such as `test/inputs` and `test/outputs`;
- existing assertion libraries such as `bats-support` and `bats-assert`;
- existing tags such as `# bats file_tags=unit` and `# bats file_tags=e2e`.

Do not bypass project targets with raw `bats` commands when wrappers exist.
The wrapper often builds binaries, injects environment variables, or runs tests
inside a controlled container.

## Suite Layout

A scalable CLI test suite usually looks like this:

```text
test/
├── setup_suite.bash
├── test_helper/
│   └── load.bash
├── inputs/
│   └── command-name/
│       └── fixture.yaml
├── outputs/
│   └── command-name/
│       └── expected.yaml
├── docker/
│   ├── Dockerfile.unit
│   └── Dockerfile.e2e
├── command-unit.bats
└── command-e2e.bats
```

Use `test/inputs/<test-file-name>/` for source fixtures and
`test/outputs/<test-file-name>/` for expected output fixtures.
This keeps a large suite navigable and lets helpers derive fixture paths from
`$BATS_TEST_FILENAME`.

## Runner and Tags

Tag files explicitly when the suite separates fast unit tests from slower e2e
tests:

```bash
#!/usr/bin/env bash
# bats file_tags=unit
```

```bash
#!/usr/bin/env bash
# bats file_tags=e2e
```

Wire tags through the project runner:

```makefile
.PHONY: test/bats/unit test/bats/e2e

test/bats/unit:
	docker build -t cli-bats-unit -f test/docker/Dockerfile.unit .
	docker run -e TERM=linux --rm \
		cli-bats-unit -F pretty --filter-tags unit,!platform ./test/*

test/bats/e2e:
	docker build -t cli-bats-e2e -f test/docker/Dockerfile.e2e .
	./scripts/run-e2e-tests.sh cli-bats-e2e
```

Use Docker when tests need a pinned Bats version, CLI binary, shell tools, or
system dependencies.
Set `TERM=linux` when the pretty formatter needs a terminal value.

Use Bats tags as the only selector for test categories, execution modes, and
platform suites.
Do not introduce custom environment variables such as `PLATFORM_TESTS=1` or
`E2E_TESTS=1` and branch on them in tests or lifecycle hooks.
Select the intended cases with `--filter-tags`, including negative tags when a
broader file tag would otherwise include a specialized test.
Within a test or per-test hook, inspect `$BATS_TEST_TAGS` when setup or helpers
must differ for that tagged case.

Environment variables are still appropriate when they are actual inputs to the
program or fixture, such as terminal width, editor selection, credentials, or a
server URL.
They must not duplicate Bats' test-selection mechanism.

## Suite Setup

Use `setup_suite.bash` for shared dependencies and suite-wide fixture roots:

```bash
setup_suite() {
  load "test_helper/load"

  ensure_installed jq git yq

  export TEST_SUITE_INPUTS="$BATS_TEST_DIRNAME/inputs"
  export TEST_SUITE_OUTPUTS="$BATS_TEST_DIRNAME/outputs"
  export TEST_GIT_REVISION="${TEST_GIT_REVISION:=undefined}"
}
```

Use `setup_file` for expensive file-level preparation and `teardown_file` for
matching cleanup:

```bash
setup_file() {
  load "test_helper/load"
  load_lib "bats-assert"

  generate_inputs "$BATS_FILE_TMPDIR"

  run_cli apply -f "'$TEST_INPUTS/**'"
  assert_success_joined_output
}

teardown_file() {
  run_cli delete -f "'$TEST_INPUTS/**'"
}
```

Use `setup` for helpers required by each test:

```bash
setup() {
  load "test_helper/load"
  load_lib "bats-support"
  load_lib "bats-assert"
}
```

Prefer Bats-managed temporary directories:

- `$BATS_TEST_TMPDIR` for per-test scratch files.
- `$BATS_FILE_TMPDIR` for files shared by tests in one `.bats` file.
- `$BATS_TMPDIR` for suite-level scratch state.

## Bats File Ordering

Keep each `.bats` test file organized from lifecycle code to test behavior to
local implementation detail.
After the shebang, file tags, and any required `load` statements, always place
functions in this order:

1. `setup_file` and `setup` functions.
2. `teardown` and `teardown_file` functions.
3. `@test` cases.
4. Local helper functions.

Helper functions belong at the bottom of the file.
Tests should read top-down as the executable specification, with helper
implementations kept after the test cases they support.
Do not place helper functions above `@test` cases just because they are used by
the setup or tests.

## Shared Helpers

Put reusable helpers in `test/test_helper/load.bash`.
Name command wrappers after the command under test, for example `run_cli` or
`run_sloctl`, so test bodies read like user workflows.

When the command under test must support pipes, shell globs, or command output
normalization, use a wrapper intentionally:

```bash
run_cli() {
  bats_require_minimum_version 1.5.0
  run --separate-stderr bash -c \
    "set -eo pipefail && my-cli $* | sed 's/ *$//'"
}
```

Use `bash -c` only for trusted test arguments.
If the test does not need shell parsing, prefer direct argument passing:

```bash
run_cli() {
  bats_require_minimum_version 1.5.0
  run --separate-stderr my-cli "$@"
}
```

When using `run --separate-stderr`, add helpers that keep failures readable:

```bash
assert_success_joined_output() {
  output+="
$stderr" assert_success
}

assert_stderr() {
  output="$stderr"
  assert_output "$@"
}
```

Load Bats libraries through a small wrapper when the runtime stores them under a
known path:

```bash
load_lib() {
  local name="$1"
  load "/usr/lib/bats/${name}/load.bash"
}
```

## Fixture Generation

Use generated fixtures when tests mutate external state or need unique resource
names.
Derive the fixture directory from the current test file:

```bash
generate_inputs() {
  load_lib "bats-support"

  local directory="$1"
  local test_filename
  test_filename="$(basename "$BATS_TEST_FILENAME" .bats)"

  TEST_INPUTS="$directory/$test_filename"
  mkdir "$TEST_INPUTS"

  local test_hash
  test_hash="${BATS_TEST_NUMBER}-$(date +%s)-$TEST_GIT_REVISION"
  TEST_PROJECT="e2e-$test_hash"

  cp -R "$TEST_SUITE_INPUTS/$test_filename/." "$TEST_INPUTS/"
  rg -l '<PROJECT>' "$TEST_INPUTS" |
    while read -r file; do
      sed -i "s/<PROJECT>/$TEST_PROJECT/g" "$file"
    done

  export TEST_INPUTS
  export TEST_PROJECT
}
```

Keep generated names stable enough to diagnose failures and unique enough to
avoid collisions across concurrent or retried e2e tests.
Include the Bats test number, timestamp, and git revision when available.

For expected outputs, copy or transform the matching output fixture directory:

```bash
generate_outputs() {
  load_lib "bats-support"

  local test_filename
  test_filename="$(basename "$BATS_TEST_FILENAME" .bats)"
  TEST_OUTPUTS="$TEST_SUITE_OUTPUTS/$test_filename"

  if [[ -z "$TEST_PROJECT" ]]; then
    fail "TEST_PROJECT is not set. Call generate_inputs first."
  fi

  rg -l '<PROJECT>' "$TEST_OUTPUTS" |
    while read -r file; do
      sed -i "s/<PROJECT>/$TEST_PROJECT/g" "$file"
    done

  export TEST_OUTPUTS
}
```

## Assertions

Use `bats-assert` and `bats-support` helpers instead of ad hoc checks:

```bash
@test "command rejects missing required flag" {
  run_cli command subcommand

  assert_failure
  assert_stderr 'Error: required flag(s) "file" not set'
}
```

Assert exact output for stable messages:

```bash
@test "command prints configured context" {
  run_cli config current-context

  assert_success_joined_output
  assert_output "minimal"
}
```

Assert expected output files for large structured output:

```bash
@test "command emits verbose yaml" {
  run_cli config current-context --verbose --output yaml

  assert_success_joined_output
  assert_output <"$TEST_OUTPUTS/current-context.yaml"
}
```

For YAML or JSON, compare normalized structures rather than raw formatting:

```bash
assert_yaml_equal() {
  local have="$1"
  local want="$2"

  assert_equal \
    "$(yq --sort-keys -y . <<<"$have")" \
    "$(yq --sort-keys -y . <<<"$want")"
}
```

Use partial or regexp assertions for variable values:

```bash
assert_stderr --partial "A copy of your changes has been stored to"
assert_output --regexp "cli/v[0-9.]+-.+"
```

## CLI Workflow Tests

Write tests as user workflows, not implementation probes:

```bash
@test "apply and delete resources from file" {
  local input="$TEST_INPUTS/resource.yaml"

  run_cli apply -f "$input"
  assert_success_joined_output
  assert_output - <<EOF
The resources were successfully applied.
EOF

  run_cli delete -f "$input"
  assert_success_joined_output
  assert_output - <<EOF
The resources were successfully deleted.
EOF
}
```

For commands with aliases or repeated flag variants, use loops to avoid
copy-paste drift:

```bash
@test "command aliases return the same object" {
  local aliases="service services svc"

  for alias in $aliases; do
    run_cli get "$alias" example-service -o yaml
    assert_success_joined_output
    assert_output <"$TEST_OUTPUTS/service.yaml"
  done
}
```

For commands that open editors or external tools, create executable wrappers in
`$BATS_TEST_TMPDIR` and pass their path through the environment:

```bash
create_editor_script() {
  local name="$1"
  local editor_script="$BATS_TEST_TMPDIR/editor-$name.sh"

  cat >"$editor_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
yq -Y -i '.metadata.labels.edited = ["true"]' "$1"
EOF
  chmod +x "$editor_script"

  printf '%s\n' "$editor_script"
}

@test "edit persists editor changes" {
  local editor_script
  editor_script="$(create_editor_script service)"

  CLI_EDITOR="$editor_script" run_cli edit service example-service

  assert_success_joined_output
  assert_output "The resources were successfully applied."
}
```

## Error and Cleanup Patterns

Test both validation errors and external-command failures:

```bash
@test "editor failure preserves changed file" {
  local editor_script
  editor_script="$(create_failing_editor)"

  CLI_EDITOR="$editor_script" run_cli edit service example-service

  assert_failure
  assert_stderr --partial "failed to run editor"
  assert_stderr --partial "A copy of your changes has been stored to"
}
```

For cleanup that talks to external systems, make the cleanup idempotent when a
failed setup may leave partial state:

```bash
teardown_file() {
  run_cli delete -f "'$TEST_INPUTS/**'" 2>/dev/null || true
}
```

Use this sparingly.
Silent cleanup can hide real teardown bugs, so keep assertions in normal cleanup
paths when the setup is expected to complete.

## Dependency Checks

Fail early when the Bats container or developer machine lacks required tools:

```bash
ensure_installed() {
  load_lib "bats-support"

  for dep in "$@"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      fail "ERROR: $dep is not installed"
    fi
  done
}
```

If a project requires a specific tool implementation, validate it directly.
For example, Python `yq` and Go `yq` are not interchangeable.

## Review Checklist

- Use project-defined runners and tags instead of raw `bats` commands.
- Use tags, not custom environment variables, to select test categories or modes.
- Keep shared command wrappers and assertion helpers in `test/test_helper`.
- Use `setup_suite`, `setup_file`, and `setup` for the right state lifetime.
- Prefer Bats temporary directories over hand-rolled `mktemp` cleanup.
- Separate stdout and stderr when testing CLI error behavior.
- Join stderr into output for success assertions when failures need both streams.
- Store large inputs and expected outputs under per-test-file fixture directories.
- Generate unique e2e resource names for mutable external systems.
- Compare structured YAML/JSON after normalization.
- Keep teardown explicit; use best-effort cleanup only for partial setup failures.
