#!/usr/bin/env bats

setup() {
  script="${BATS_TEST_DIRNAME}/../scripts/find-review-file.sh"
  review_meta="${BATS_TEST_DIRNAME}/../../review-pr/scripts/review-meta.sh"
  mock_bin="${BATS_TEST_TMPDIR}/bin"
  repository="${BATS_TEST_TMPDIR}/repository"
  mkdir -p -- "${mock_bin}" "${repository}"
  cp -- "${BATS_TEST_DIRNAME}/fixtures/gh-review-file" "${mock_bin}/gh"
  chmod +x "${mock_bin}/gh"
  export PATH="${mock_bin}:${PATH}"
  export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
  git -C "${repository}" init --quiet -b main
  cd "${repository}" || return 1
}

write_review() {
  local outfile="$1"

  jq -n \
    --arg repo example/private \
    --arg branch feature/private \
    '{
      version: 1,
      timestamp: "2026-08-19T12:00:00Z",
      repo: $repo,
      branch: $branch,
      base_ref: "main",
      base_commit_id: "base1",
      commit_id: "head1",
      pr_number: 7,
      aspects: ["code"],
      findings: []
    }' >"${outfile}"
}

@test "finds a review reserved by review-meta" {
  metadata="$("${review_meta}" --pr-number 7)"
  outfile="$(jq -r '.outfile' <<<"${metadata}")"
  write_review "${outfile}"

  run "${script}" --branch feature/private

  [ "${status}" -eq 0 ]
  [ "${output}" = "${outfile}" ]
}

@test "ignores a newer incomplete reservation" {
  metadata="$("${review_meta}" --pr-number 7)"
  outfile="$(jq -r '.outfile' <<<"${metadata}")"
  write_review "${outfile}"
  incomplete="$(dirname "${outfile}")/newer.json"
  jq -n \
    --arg repo example/private \
    --arg branch feature/private \
    '{version: 1, repo: $repo, branch: $branch}' >"${incomplete}"
  touch -d '2030-01-01T00:00:00Z' "${incomplete}"

  run "${script}" --branch feature/private

  [ "${status}" -eq 0 ]
  [ "${output}" = "${outfile}" ]
}

@test "requires an explicit branch in a detached checkout" {
  git commit --quiet --allow-empty -m initial
  git switch --quiet --detach

  run "${script}"

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"detached HEAD requires --branch"* ]]
}
