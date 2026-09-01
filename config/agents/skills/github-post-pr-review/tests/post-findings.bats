setup() {
  bats_require_minimum_version 1.5.0
  skill_dir="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  script="${skill_dir}/scripts/post-findings.sh"
  mock_bin="${BATS_TEST_TMPDIR}/bin"
  mkdir -p -- "${mock_bin}"
  cp -- "${BATS_TEST_DIRNAME}/fixtures/gh" "${mock_bin}/gh"
  chmod +x "${mock_bin}/gh"
  export PATH="${mock_bin}:${PATH}"
  export GH_LOG="${BATS_TEST_TMPDIR}/gh.log"
  export GH_PAYLOAD="${BATS_TEST_TMPDIR}/payload.json"
  export GH_REQUEST_LOG="${BATS_TEST_TMPDIR}/gh-requests.log"
  export GH_STATE_DIR="${BATS_TEST_TMPDIR}/gh-state"
  export GH_SCENARIO=default
  mkdir -p -- "${GH_STATE_DIR}"
  : >"${GH_LOG}"
  : >"${GH_REQUEST_LOG}"
  printf '[]\n' >"${BATS_TEST_TMPDIR}/body.json"
}

@test "relocates invalid right-side positions without failing valid comments" {
  printf '%s\n' \
    '[{"file":"a.go","line":2,"severity":"important","description":"valid"},{"file":"a.go","line":99,"severity":"important","description":"relocated"}]' \
    >"${BATS_TEST_TMPDIR}/inline.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.inline_comments_posted' <<<"${output}")" -eq 1 ]
  [ "$(jq -r '.relocated_findings' <<<"${output}")" -eq 1 ]
  jq -e '.comments | length == 1 and .[0].line == 2' "${GH_PAYLOAD}"
  jq -e '.body | contains("`a.go:99`")' "${GH_PAYLOAD}"
  [ "$(wc -l <"${GH_LOG}")" -eq 1 ]
  [ "$(tail -n 2 "${GH_REQUEST_LOG}")" = $'GET repos/o/r/pulls/1\nPOST repos/o/r/pulls/1/reviews' ]
}

@test "rejects a stale base before a GitHub write" {
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id stale-base \
    --commit-id head1 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"does not match current PR base"* ]]
  [ ! -s "${GH_LOG}" ]
}

@test "retains a file that appears only on a later API page" {
  export GH_SCENARIO=second-page
  printf '%s\n' \
    '[{"file":"later.go","line":10,"description":"later page"}]' \
    >"${BATS_TEST_TMPDIR}/inline.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 0 ]
  jq -e '.comments | length == 1 and .[0].path == "later.go"' "${GH_PAYLOAD}"
}

@test "rejects a non-positive inline line before a GitHub request" {
  printf '%s\n' \
    '[{"file":"a.go","line":0,"description":"invalid"}]' \
    >"${BATS_TEST_TMPDIR}/inline.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"inline findings contain invalid entries"* ]]
  [ ! -s "${GH_LOG}" ]
}

@test "rejects a pending review attached to another commit" {
  export GH_SCENARIO=review-wrong-commit
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --review-id 44 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"targets a different PR commit"* ]]
  [ ! -s "${GH_LOG}" ]
}

@test "rejects a head change immediately before creating a review" {
  export GH_SCENARIO=head-mutates
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"review commit head1 does not match current PR head head2"* ]]
  [ ! -s "${GH_LOG}" ]
  [ "$(rg -c '^GET repos/o/r/pulls/1$' "${GH_REQUEST_LOG}")" -eq 2 ]
}

@test "rejects a base change immediately before updating a review" {
  export GH_SCENARIO=base-mutates
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --review-id 44 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"review base base1 does not match current PR base base2"* ]]
  [ ! -s "${GH_LOG}" ]
  [ "$(rg -c '^GET repos/o/r/pulls/1$' "${GH_REQUEST_LOG}")" -eq 2 ]
}

@test "confirms a created review after a malformed POST response" {
  export GH_SCENARIO=post-malformed-response
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.review_id' <<<"${output}")" -eq 99 ]
  [ "$(jq -r '.state' <<<"${output}")" = PENDING ]
  [ "$(jq -r '.commit_id' <<<"${output}")" = head1 ]
  [ "$(tail -n 1 "${GH_REQUEST_LOG}")" = "GET repos/o/r/pulls/1/reviews" ]
}

@test "confirms a created review after a mismatched POST response" {
  export GH_SCENARIO=post-mismatched-response
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.review_id' <<<"${output}")" -eq 99 ]
  [ "$(jq -r '.state' <<<"${output}")" = PENDING ]
  [ "$(jq -r '.commit_id' <<<"${output}")" = head1 ]
  [ "$(tail -n 1 "${GH_REQUEST_LOG}")" = "GET repos/o/r/pulls/1/reviews/99" ]
}

@test "does not confirm an identical review owned by another user" {
  export GH_SCENARIO=post-other-user-only
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"matching reviews: 0"* ]]
  [ "$(rg -c '^GET user$' "${GH_REQUEST_LOG}")" -eq 1 ]
}

@test "confirms the current user's review among identical reviews" {
  export GH_SCENARIO=post-current-and-other-users
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.review_id' <<<"${output}")" -eq 99 ]
  [ "$(jq -r '.state' <<<"${output}")" = PENDING ]
  [ "$(rg -c '^GET user$' "${GH_REQUEST_LOG}")" -eq 1 ]
}

@test "rejects an ambiguous confirmation after a malformed POST response" {
  export GH_SCENARIO=post-ambiguous-response
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"could not identify the created review after an invalid POST response (matching reviews: 2)"* ]]
  [ "$(wc -l <"${GH_LOG}")" -eq 1 ]
}

@test "confirms an updated review after a mismatched PUT response" {
  export GH_SCENARIO=put-mismatched-response
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --review-id 44 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.review_id' <<<"${output}")" -eq 44 ]
  [ "$(jq -r '.state' <<<"${output}")" = PENDING ]
  [ "$(jq -r '.commit_id' <<<"${output}")" = head1 ]
  [ "$(rg -B 1 '^PUT ' "${GH_REQUEST_LOG}")" = $'GET repos/o/r/pulls/1\nPUT repos/o/r/pulls/1/reviews/44' ]
  [ "$(tail -n 1 "${GH_REQUEST_LOG}")" = "GET repos/o/r/pulls/1/reviews/44" ]
}

@test "rejects an updated review that is no longer pending" {
  export GH_SCENARIO=put-non-pending
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --review-id 44 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"review 44 is not pending after update (state: APPROVED)"* ]]
  [ "$(wc -l <"${GH_LOG}")" -eq 1 ]
}

@test "confirms a created review after POST persists and exits nonzero" {
  export GH_SCENARIO=post-write-fails-persisted
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run --separate-stderr "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.review_id' <<<"${output}")" -eq 99 ]
  [ "$(jq -r '.state' <<<"${output}")" = PENDING ]
  [ "$(jq -r '.commit_id' <<<"${output}")" = head1 ]
  [[ "${stderr}" == *"WARNING: GitHub POST exited with status 54, but the pending review was confirmed."* ]]
  [[ "${stderr}" == *"gh: simulated POST transport failure"* ]]
}

@test "confirms an updated review after PUT persists and exits nonzero" {
  export GH_SCENARIO=put-write-fails-persisted
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run --separate-stderr "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --review-id 44 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 0 ]
  [ "$(jq -r '.review_id' <<<"${output}")" -eq 44 ]
  [ "$(jq -r '.state' <<<"${output}")" = PENDING ]
  [ "$(jq -r '.commit_id' <<<"${output}")" = head1 ]
  [[ "${stderr}" == *"WARNING: GitHub PUT exited with status 55, but the pending review was confirmed."* ]]
  [[ "${stderr}" == *"gh: simulated PUT transport failure"* ]]
}

@test "reports an unknown outcome after a failed POST has ambiguous matches" {
  export GH_SCENARIO=post-write-fails-ambiguous
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run --separate-stderr "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 54 ]
  [ -z "${output}" ]
  [ "$(head -n 1 <<<"${stderr}")" = "gh: simulated POST transport failure" ]
  [[ "${stderr}" == *"GitHub POST exited with status 54; write outcome is unknown."* ]]
  [[ "${stderr}" == *"matching reviews: 2"* ]]
}

@test "reports an unknown outcome after a failed PUT is not persisted" {
  export GH_SCENARIO=put-write-fails-unconfirmed
  printf '[]\n' >"${BATS_TEST_TMPDIR}/inline.json"
  printf '%s\n' '[{"description":"finding"}]' >"${BATS_TEST_TMPDIR}/body.json"

  run --separate-stderr "${script}" \
    --repo o/r \
    --pr-number 1 \
    --base-commit-id base1 \
    --commit-id head1 \
    --review-id 44 \
    --inline-findings "${BATS_TEST_TMPDIR}/inline.json" \
    --non-inline-findings "${BATS_TEST_TMPDIR}/body.json"

  [ "${status}" -eq 55 ]
  [ -z "${output}" ]
  [ "$(head -n 1 <<<"${stderr}")" = "gh: simulated PUT transport failure" ]
  [[ "${stderr}" == *"GitHub PUT exited with status 55; write outcome is unknown."* ]]
  [[ "${stderr}" == *"review 44 body does not match the update"* ]]
}
