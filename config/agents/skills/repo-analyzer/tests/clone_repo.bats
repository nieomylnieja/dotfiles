#!/usr/bin/env bats

setup() {
  script="${BATS_TEST_DIRNAME}/../scripts/clone_repo.sh"
  clone_base="${BATS_TEST_TMPDIR}/repositories"
  repository="${clone_base}/github.com/example/project"
  mkdir -p "${repository}"
  git -C "${repository}" init --quiet
  git -C "${repository}" config user.email test@example.com
  git -C "${repository}" config user.name Test
  printf 'content\n' >"${repository}/tracked.txt"
  git -C "${repository}" add tracked.txt
  git -C "${repository}" commit --quiet -m initial
}

@test "reuses a clean clone with the requested origin" {
  git -C "${repository}" remote add origin \
    https://github.com/example/project.git

  run "${script}" --base "${clone_base}" --url example/project

  [ "${status}" -eq 0 ]
  [ "${output}" = "${repository}" ]
}

@test "rejects a clone whose origin identifies another repository" {
  git -C "${repository}" remote add origin \
    https://github.com/attacker/other.git

  run "${script}" --base "${clone_base}" --url example/project

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"managed clone origin does not match requested repository"* ]]
}

@test "rejects local changes before reusing a clone" {
  git -C "${repository}" remote add origin \
    git@github.com:example/project.git
  printf 'user data\n' >"${repository}/untracked.txt"

  run "${script}" --base "${clone_base}" --url example/project

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"managed clone has local changes"* ]]
}

@test "fails closed when another clone wins the destination race" {
  mock_bin="${BATS_TEST_TMPDIR}/bin"
  race_destination="${clone_base}/github.com/example/race"
  mkdir -p "${mock_bin}"
  export RACE_DESTINATION="${race_destination}"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'if [[ "$1" == clone ]]; then' \
    '  clone_destination="${!#}"' \
    '  mkdir -p "${clone_destination}/.git" "${RACE_DESTINATION}/.git"' \
    '  printf "winner\n" >"${RACE_DESTINATION}/tracked.txt"' \
    '  exit 0' \
    'fi' \
    'printf "unexpected git command: %s\n" "$*" >&2' \
    'exit 2' >"${mock_bin}/git"
  chmod +x "${mock_bin}/git"
  export PATH="${mock_bin}:${PATH}"

  run "${script}" --base "${clone_base}" --url example/race

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"destination appeared during clone"* ]]
  [ -f "${race_destination}/tracked.txt" ]
  [ "$(fd -t d '^race\.tmp\.' "$(dirname "${race_destination}")" | wc -l)" -eq 0 ]
}
