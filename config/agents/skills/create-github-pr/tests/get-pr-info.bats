setup() {
  script="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)/get-pr-info.sh"
  repo="${BATS_TEST_TMPDIR}/repo"
  remote="${BATS_TEST_TMPDIR}/remote.git"
  mock_bin="${BATS_TEST_TMPDIR}/bin"
  mkdir -p -- "${mock_bin}"
  cp -- "${BATS_TEST_DIRNAME}/fixtures/gh" "${mock_bin}/gh"
  chmod +x "${mock_bin}/gh"
  export PATH="${mock_bin}:${PATH}"
  export GH_FAIL=false
  export GH_PR_LIST='[]'

  git init --quiet --bare "${remote}"
  git init --quiet "${repo}"
  git -C "${repo}" config user.email test@example.com
  git -C "${repo}" config user.name Test
  git -C "${repo}" switch --quiet -c main
  touch "${repo}/old name.txt"
  git -C "${repo}" add -- "old name.txt"
  git -C "${repo}" commit --quiet -m initial
  git -C "${repo}" remote add origin "${remote}"
  git -C "${repo}" push --quiet --set-upstream origin main
  git --git-dir "${remote}" symbolic-ref HEAD refs/heads/main
  git -C "${repo}" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git -C "${repo}" switch --quiet -c feature
  git -C "${repo}" commit --quiet --allow-empty -m feature
}

write_mock() {
  local name="$1"
  shift

  printf '%s\n' "$@" >"${mock_bin}/${name}"
  chmod +x "${mock_bin}/${name}"
}

pr_info() {
  cd "${repo}" || return
  "${script}" --base main
}

pr_info_default() {
  cd "${repo}" || return
  "${script}"
}

@test "parses spaces and rename records from NUL-delimited status" {
  git -C "${repo}" mv -- "old name.txt" "new name.txt"
  touch "${repo}/untracked file.txt"

  run pr_info

  [ "${status}" -eq 0 ]
  result="${output}"
  jq -e '
    any(.uncommitted_files[]; .status | test("R"))
    and any(.uncommitted_files[]; .path == "new name.txt" and .original_path == "old name.txt")
    and any(.uncommitted_files[]; .status == "??" and .path == "untracked file.txt")
  ' <<<"${result}"
}

@test "rejects a stale cached base" {
  updater="${BATS_TEST_TMPDIR}/updater"
  git clone --quiet "${remote}" "${updater}"
  git -C "${updater}" config user.email test@example.com
  git -C "${updater}" config user.name Test
  git -C "${updater}" commit --quiet --allow-empty -m remote-update
  git -C "${updater}" push --quiet origin main

  run pr_info

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"but the remote base is"* ]]
}

@test "uses the current remote default instead of cached origin HEAD" {
  git -C "${repo}" branch release main
  git -C "${repo}" push --quiet origin release
  git --git-dir "${remote}" symbolic-ref HEAD refs/heads/release
  export GH_EXPECTED_BASE=release

  run pr_info_default

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.base_branch' <<<"${output}")" = release ]
  [ "$(git -C "${repo}" symbolic-ref refs/remotes/origin/HEAD)" = \
    refs/remotes/origin/main ]
}

@test "preserves a GitHub lookup failure" {
  export GH_FAIL=true

  run pr_info

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"gh: pull request lookup failed"* ]]
}

@test "returns only exact head and base pull request metadata" {
  export GH_PR_LIST='[{"number":11,"url":"https://example.test/pr/11","baseRefName":"release","headRefName":"feature"},{"number":12,"url":"https://example.test/pr/12","baseRefName":"main","headRefName":"feature"}]'

  run pr_info

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.existing_pr_number' <<<"${output}")" -eq 12 ]
  [ "$(jq -r '.existing_pr_base' <<<"${output}")" = "main" ]
}

@test "ignores a pull request for a different base" {
  export GH_PR_LIST='[{"number":11,"url":"https://example.test/pr/11","baseRefName":"release","headRefName":"feature"}]'

  run pr_info

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.existing_pr_number' <<<"${output}")" = "null" ]
}

@test "rejects ambiguous exact pull request matches" {
  export GH_PR_LIST='[{"number":11,"url":"https://example.test/pr/11","baseRefName":"main","headRefName":"feature"},{"number":12,"url":"https://example.test/pr/12","baseRefName":"main","headRefName":"feature"}]'

  run pr_info

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"multiple open pull requests match head 'feature' and base 'main'"* ]]
}

@test "preserves a rev-list failure before parsing counts" {
  git -C "${repo}" branch --set-upstream-to=origin/main feature
  REAL_GIT="$(command -v git)"
  export REAL_GIT
  write_mock git \
    '#!/usr/bin/env bash' \
    'if [[ "$1" == rev-list ]]; then' \
    '  printf '\''git: rev-list fixture failure\n'\'' >&2' \
    '  exit 74' \
    'fi' \
    'exec "${REAL_GIT}" "$@"'

  run pr_info

  [ "${status}" -eq 74 ]
  [[ "${output}" == *"git: rev-list fixture failure"* ]]
}

@test "rejects detached HEAD" {
  git -C "${repo}" checkout --quiet --detach

  run pr_info

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"not on a branch"* ]]
}
