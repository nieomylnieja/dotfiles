#!/usr/bin/env bats

setup() {
  script="${BATS_TEST_DIRNAME}/../scripts/get-commit-info.sh"
  repository="${BATS_TEST_TMPDIR}/repository"
  mkdir -p "${repository}"
  git -C "${repository}" init --quiet -b task-123
  git -C "${repository}" config user.email test@example.com
  git -C "${repository}" config user.name Test
  printf 'initial\n' >"${repository}/old name.txt"
  git -C "${repository}" add "old name.txt"
  git -C "${repository}" commit --quiet -m initial
  cd "${repository}" || return 1
}

@test "reports a clean working tree as bounded JSON" {
  run "${script}"

  [ "${status}" -eq 0 ]
  printf '%s\n' "${output}" |
    jq -e '
      .current_branch == "task-123"
      and .nothing_to_commit
      and (.staged_files | length == 0)
      and (.unstaged_files | length == 0)
      and (.recent_commits | length == 1)
      and (.recent_commits[0].hash | test("^[0-9a-f]+$"))
      and (.recent_commits[0].message == "initial")
      and .issue_number == "123"
      and (has("staged_diff") | not)
    '
}

@test "supports the first commit on an unborn branch" {
  unborn="${BATS_TEST_TMPDIR}/unborn"
  mkdir -p "${unborn}"
  git -C "${unborn}" init --quiet -b initial
  cd "${unborn}" || return 1

  run "${script}"

  [ "${status}" -eq 0 ]
  printf '%s\n' "${output}" |
    jq -e '
      .current_branch == "initial"
      and (.recent_commits | length == 0)
      and .nothing_to_commit
    '
}

@test "preserves both paths for a staged rename" {
  git mv "old name.txt" "new name.txt"

  run "${script}"

  [ "${status}" -eq 0 ]
  printf '%s\n' "${output}" |
    jq -e '
      .staged_files == [{
        status: "R100",
        old_path: "old name.txt",
        path: "new name.txt"
      }]
    '
}

@test "does not print staged file contents" {
  printf 'PRIVATE-STAGED-CONTENT\n' >>"old name.txt"
  git add "old name.txt"

  run "${script}"

  [ "${status}" -eq 0 ]
  [[ "${output}" != *"PRIVATE-STAGED-CONTENT"* ]]
}

@test "fails outside a Git repository" {
  outside="${BATS_TEST_TMPDIR}/outside"
  mkdir -p "${outside}"
  cd "${outside}" || return 1

  run "${script}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"not a git repository"* ]]
}
