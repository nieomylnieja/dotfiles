setup() {
  bats_require_minimum_version 1.5.0
  script="$(cd "${BATS_TEST_DIRNAME}/../scripts" && pwd)/worktree-setup.sh"
  repo="${BATS_TEST_TMPDIR}/repo"
  remote="${BATS_TEST_TMPDIR}/remote.git"
  mock_bin="${BATS_TEST_TMPDIR}/bin"

  mkdir -p -- "${mock_bin}"

  git init --quiet --bare "${remote}"
  git init --quiet "${repo}"
  git -C "${repo}" config user.email test@example.com
  git -C "${repo}" config user.name Test
  git -C "${repo}" switch --quiet -c main
  git -C "${repo}" commit --quiet --allow-empty -m initial
  git -C "${repo}" remote add origin "${remote}"
  git -C "${repo}" push --quiet --set-upstream origin main
  git -C "${repo}" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
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
  for command_name in bash git jq mkdir; do
    ln -s -- "$(command -v "${command_name}")" "${restricted_path}/${command_name}"
  done
  printf '%s\n' "${restricted_path}"
}

worktree_setup() {
  cd "${repo}" || return
  "${script}" "$@"
}

@test "creates and verifies an exact detached commit checkout" {
  head_commit="$(git -C "${repo}" rev-parse HEAD)"

  run worktree_setup --commit "${head_commit}" review/pr-1

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.head' <<<"${output}")" = "${head_commit}" ]
  [ "$(jq -r '.branch' <<<"${output}")" = "null" ]
  [ "$(git -C "${repo}/.worktrees/review/pr-1" rev-parse HEAD)" = "${head_commit}" ]
}

@test "reuses a dirty worktree without resetting it" {
  git -C "${repo}" branch feature
  worktree_setup feature >/dev/null
  printf 'local change\n' >"${repo}/.worktrees/feature/local.txt"

  run worktree_setup feature

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.dirty' <<<"${output}")" = "true" ]
  [ "$(<"${repo}/.worktrees/feature/local.txt")" = "local change" ]
}

@test "rejects a branch-attached checkout in exact commit mode" {
  head_commit="$(git -C "${repo}" rev-parse HEAD)"
  git -C "${repo}" branch review/pr-7
  mkdir -p "${repo}/.worktrees/review"
  git -C "${repo}" worktree add --quiet \
    "${repo}/.worktrees/review/pr-7" review/pr-7

  run worktree_setup --commit "${head_commit}" review/pr-7

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"expected a detached checkout"* ]]
}

@test "fails closed when the remote branch probe has an operational error" {
  git -C "${repo}" remote set-url origin "${BATS_TEST_TMPDIR}/missing.git"

  run worktree_setup --fetch feature

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"cannot probe remote branch 'feature'"* ]]
  [ ! -e "${repo}/.worktrees/feature" ]
}

@test "preserves a worktree-list failure" {
  REAL_GIT="$(command -v git)"
  export REAL_GIT
  export GIT_SCENARIO=worktree-list-error
  write_mock git \
    '#!/usr/bin/env bash' \
    'if [[ "${GIT_SCENARIO:-}" == worktree-list-error && "$*" == "worktree list --porcelain" ]]; then' \
    '  printf '\''git: worktree list fixture failure\n'\'' >&2' \
    '  exit 73' \
    'fi' \
    'exec "${REAL_GIT}" "$@"'
  export PATH="${mock_bin}:${PATH}"

  run worktree_setup feature

  [ "${status}" -eq 73 ]
  [[ "${output}" == *"git: worktree list fixture failure"* ]]
  [ ! -e "${repo}/.worktrees/feature" ]
}

@test "preserves a missing rg failure" {
  restricted_path="$(path_without_rg)"
  bash_path="$(command -v bash)"
  cd "${repo}" || return

  run -127 /usr/bin/env PATH="${restricted_path}" "${bash_path}" "${script}" feature

  [ "${status}" -eq 127 ]
  [[ "${output}" == *"rg: command not found"* ]]
  [ ! -e "${repo}/.worktrees/feature" ]
}

@test "preserves rg status 2" {
  write_mock rg \
    '#!/usr/bin/env bash' \
    'printf '\''rg: fixture failure\n'\'' >&2' \
    'exit 2'
  export PATH="${mock_bin}:${PATH}"

  run worktree_setup feature

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"rg: fixture failure"* ]]
  [ ! -e "${repo}/.worktrees/feature" ]
}

@test "creates a missing remote branch from the explicit base" {
  run worktree_setup --fetch --base main feature/new

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.branch' <<<"${output}")" = "feature/new" ]
  [ "$(git -C "${repo}/.worktrees/feature/new" merge-base main HEAD)" = "$(git -C "${repo}" rev-parse main)" ]
}

@test "rejects hidden-file copy options" {
  printf 'secret\n' >"${repo}/.env"

  run worktree_setup --copy-local-hidden .env feature

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"unknown option: --copy-local-hidden"* ]]
  [ ! -e "${repo}/.worktrees/feature/.env" ]
}

@test "rejects an existing path checked out on another branch" {
  git -C "${repo}" branch other
  mkdir -p "${repo}/.worktrees"
  git -C "${repo}" worktree add --quiet "${repo}/.worktrees/expected" other

  run worktree_setup expected

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"contains branch 'other', expected 'expected'"* ]]
}
