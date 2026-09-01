#!/usr/bin/env bats

setup() {
  script="${BATS_TEST_DIRNAME}/../scripts/review-meta.sh"
  mock_bin="${BATS_TEST_TMPDIR}/bin"
  mkdir -p -- "${mock_bin}"
  cp -- "${BATS_TEST_DIRNAME}/fixtures/gh" "${mock_bin}/gh"
  chmod +x "${mock_bin}/gh"
  export PATH="${mock_bin}:${PATH}"
  export GH_SCENARIO=meta
  export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
  umask 022
}

@test "reserves a private unique review output file" {
  run "${script}" --pr-number 7

  [ "${status}" -eq 0 ]
  first_output="$(jq -r '.outfile' <<<"${output}")"
  [ -f "${first_output}" ]
  [ "$(stat -c '%a' "${first_output}")" = 600 ]
  [ "$(stat -c '%a' "$(dirname "${first_output}")")" = 700 ]

  run "${script}" --pr-number 7

  [ "${status}" -eq 0 ]
  second_output="$(jq -r '.outfile' <<<"${output}")"
  [ -f "${second_output}" ]
  [ "${first_output}" != "${second_output}" ]
}
