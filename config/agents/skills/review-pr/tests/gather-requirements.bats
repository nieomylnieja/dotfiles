setup() {
  bats_require_minimum_version 1.5.0
  script="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)/gather-requirements.sh"
  repo="${BATS_TEST_TMPDIR}/repo"
  mock_bin="${BATS_TEST_TMPDIR}/bin"
  mkdir -p -- "${mock_bin}"
  cp -- "${BATS_TEST_DIRNAME}/fixtures/gh" "${mock_bin}/gh"
  chmod +x "${mock_bin}/gh"
  export PATH="${mock_bin}:${PATH}"
  git init --quiet "${repo}"
  git -C "${repo}" switch --quiet -c main
}

write_mock() {
  local name="$1"
  shift

  printf '%s\n' "$@" >"${mock_bin}/${name}"
  chmod +x "${mock_bin}/${name}"
}

path_without_rg() {
  local restricted_path="${BATS_TEST_TMPDIR}/path-without-rg"
  local command_name

  mkdir -p -- "${restricted_path}"
  for command_name in bash git gh jq sed sort; do
    ln -s -- "$(command -v "${command_name}")" "${restricted_path}/${command_name}"
  done
  printf '%s\n' "${restricted_path}"
}

gather() {
  cd "${repo}" || return
  "${script}" "$@"
}

@test "reports a confirmed absence without hiding a command failure" {
  export GH_SCENARIO=no-pr

  run gather

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.source' <<<"${output}")" = "none" ]
}

@test "preserves a linked GitHub issue access failure" {
  export GH_SCENARIO=issue-error

  run gather --pr-number 7

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"gh: issue access denied"* ]]
  [[ "${output}" != *'"source":"none"'* ]]
}

@test "preserves a pull request lookup failure" {
  export GH_SCENARIO=pr-error

  run gather --pr-number 7

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"gh: authentication failed"* ]]
}

@test "preserves a missing rg failure" {
  export GH_SCENARIO=criteria
  restricted_path="$(path_without_rg)"
  bash_path="$(command -v bash)"
  cd "${repo}" || return

  run -127 /usr/bin/env PATH="${restricted_path}" "${bash_path}" "${script}" --pr-number 7

  [ "${status}" -eq 127 ]
  [[ "${output}" == *"rg: command not found"* ]]
  [[ "${output}" != *'"source":"none"'* ]]
}

@test "preserves rg status 2" {
  export GH_SCENARIO=criteria
  write_mock rg \
    '#!/usr/bin/env bash' \
    'printf '\''rg: invalid option\n'\'' >&2' \
    'exit 2'

  run gather --pr-number 7

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"rg: invalid option"* ]]
  [[ "${output}" != *'"source":"none"'* ]]
}

@test "preserves a sort failure while collecting linked issues" {
  export GH_SCENARIO=issue-error
  write_mock sort \
    '#!/usr/bin/env bash' \
    'printf '\''sort: fixture failure\n'\'' >&2' \
    'exit 71'

  run gather --pr-number 7

  [ "${status}" -eq 71 ]
  [[ "${output}" == *"sort: fixture failure"* ]]
}

@test "preserves a sed failure while selecting a Jira key" {
  export GH_SCENARIO=jira
  write_mock sed \
    '#!/usr/bin/env bash' \
    'printf '\''sed: fixture failure\n'\'' >&2' \
    'exit 72'

  run gather --pr-number 7

  [ "${status}" -eq 72 ]
  [[ "${output}" == *"sed: fixture failure"* ]]
}

@test "returns explicit acceptance criteria from the PR body" {
  export GH_SCENARIO=criteria

  run gather --pr-number 7

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.source' <<<"${output}")" = "pr-description" ]
  [[ "$(jq -r '.requirements' <<<"${output}")" == *"Acceptance criteria"* ]]
}

@test "rejects a missing option value with a usage status" {
  run gather --pr-number

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"--pr-number requires an argument"* ]]
}
