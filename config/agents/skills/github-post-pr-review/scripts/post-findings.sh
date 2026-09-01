#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"
readonly REVIEW_MARKER="<!-- github-post-pr-review -->"
readonly REVIEW_SECTION_START="<!-- github-post-pr-review:non-inline:start -->"
readonly REVIEW_SECTION_END="<!-- github-post-pr-review:non-inline:end -->"
tmp_dir=""

usage() {
  cat <<EOF
Usage: ${PROG} [OPTION]...
Post verified findings as a pending GitHub pull request review.

Required options:
  --repo OWNER/REPO
  --pr-number NUMBER
  --base-commit-id SHA
  --commit-id SHA
  --inline-findings FILE
  --non-inline-findings FILE

Optional:
  --review-id ID|null  update this compatible pending review body
  -h, --help           display this help and exit
EOF
}

fatal() {
  local message="$1"
  local status="${2:-1}"

  printf '%s: ERROR: %s\n' "${PROG}" "${message}" >&2
  exit "${status}"
}

cleanup() {
  if [[ -n "${tmp_dir}" && -d "${tmp_dir}" ]]; then
    rm -rf -- "${tmp_dir}"
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fatal "required command not found: $1"
}

validate_findings() {
  local inline_file="$1"
  local body_file="$2"

  jq -e '
    type == "array"
    and all(
      .[];
      (.file | type == "string" and length > 0)
      and (.line | type == "number" and . > 0 and floor == .)
      and (.description | type == "string" and length > 0)
      and ((.severity // "important") | type == "string")
    )
  ' "${inline_file}" >/dev/null ||
    fatal "inline findings contain invalid entries: ${inline_file}" 2
  jq -e '
    type == "array"
    and all(
      .[];
      (.description | type == "string" and length > 0)
      and ((.severity // "important") | type == "string")
    )
  ' "${body_file}" >/dev/null ||
    fatal "non-inline findings contain invalid entries: ${body_file}" 2
}

diff_position_index() {
  jq '
    map({
      key: .filename,
      value: (
        ((.patch // "") | split("\n")) as $lines
        | reduce $lines[] as $line
            ({next: null, valid: []};
              if ($line | startswith("@@ ")) then
                ($line
                  | capture("^@@ -[0-9]+(?:,[0-9]+)? \\+(?<start>[0-9]+)(?:,[0-9]+)? @@")
                ) as $hunk
                | .next = ($hunk.start | tonumber)
              elif .next == null or ($line | startswith("\\")) then
                .
              elif ($line | startswith("-")) then
                .
              else
                .valid += [.next]
                | .next += 1
              end)
        | .valid
      )
    })
    | from_entries
  '
}

validate_current_pr() {
  local repo="$1"
  local pr_number="$2"
  local expected_base="$3"
  local expected_head="$4"
  local pr_json
  local current_base
  local current_head

  pr_json="$(gh api "repos/${repo}/pulls/${pr_number}")"
  jq -e '
    type == "object"
    and (.base.sha | type == "string" and length > 0)
    and (.head.sha | type == "string" and length > 0)
  ' <<<"${pr_json}" >/dev/null ||
    fatal "current pull request response is invalid"

  current_base="$(jq -r '.base.sha' <<<"${pr_json}")"
  current_head="$(jq -r '.head.sha' <<<"${pr_json}")"
  [[ "${current_base}" == "${expected_base}" ]] ||
    fatal "review base ${expected_base} does not match current PR base ${current_base}"
  [[ "${current_head}" == "${expected_head}" ]] ||
    fatal "review commit ${expected_head} does not match current PR head ${current_head}"
}

review_response_is_valid() {
  local response_file="$1"
  local expected_id="$2"
  local expected_commit="$3"
  local expected_login="$4"

  jq -e \
    --arg expected_id "${expected_id}" \
    --arg expected_commit "${expected_commit}" \
    --arg expected_login "${expected_login}" '
      type == "object"
      and (.id | type == "number" and . > 0 and floor == .)
      and ($expected_id == "" or (.id | tostring) == $expected_id)
      and .state == "PENDING"
      and .commit_id == $expected_commit
      and .user.login == $expected_login
    ' "${response_file}" >/dev/null 2>&1
}

validate_confirmed_review() {
  local review_json="$1"
  local expected_id="$2"
  local expected_commit="$3"
  local expected_login="$4"
  local operation="$5"
  local actual_id
  local actual_state
  local actual_commit
  local actual_login

  jq -e '
    type == "object"
    and (.id | type == "number" and . > 0 and floor == .)
    and (.state | type == "string" and length > 0)
    and (.commit_id | type == "string" and length > 0)
    and (.user.login | type == "string" and length > 0)
  ' <<<"${review_json}" >/dev/null ||
    fatal "${operation} confirmation returned invalid review data"

  actual_id="$(jq -r '.id' <<<"${review_json}")"
  actual_state="$(jq -r '.state' <<<"${review_json}")"
  actual_commit="$(jq -r '.commit_id' <<<"${review_json}")"
  actual_login="$(jq -r '.user.login' <<<"${review_json}")"
  [[ "${actual_id}" == "${expected_id}" ]] ||
    fatal "${operation} confirmation returned review ${actual_id}, expected ${expected_id}"
  [[ "${actual_state}" == "PENDING" ]] ||
    fatal "review ${actual_id} is not pending after ${operation} (state: ${actual_state})"
  [[ "${actual_commit}" == "${expected_commit}" ]] ||
    fatal "review ${actual_id} targets ${actual_commit} after ${operation}, expected ${expected_commit}"
  [[ "${actual_login}" == "${expected_login}" ]] ||
    fatal "review ${actual_id} belongs to ${actual_login} after ${operation}, expected ${expected_login}"

  printf '%s\n' "${review_json}"
}

validate_owned_pending_review() {
  local review_json="$1"
  local review_id="$2"
  local expected_commit="$3"
  local expected_login="$4"

  [[ "$(jq -r '.state' <<<"${review_json}")" == "PENDING" ]] ||
    fatal "review ${review_id} is not pending"
  [[ "$(jq -r '.commit_id' <<<"${review_json}")" == "${expected_commit}" ]] ||
    fatal "pending review ${review_id} targets a different PR commit"
  [[ "$(jq -r '.user.login // ""' <<<"${review_json}")" == "${expected_login}" ]] ||
    fatal "pending review ${review_id} belongs to a different GitHub user"
  [[ "$(jq -r '.body // ""' <<<"${review_json}")" == *"${REVIEW_MARKER}"* ]] ||
    fatal "pending review ${review_id} is not managed by this skill"
}

confirm_updated_review() {
  local repo="$1"
  local pr_number="$2"
  local review_id="$3"
  local expected_commit="$4"
  local expected_body="$5"
  local expected_login="$6"
  local review_json

  review_json="$(gh api "repos/${repo}/pulls/${pr_number}/reviews/${review_id}")"
  validate_confirmed_review \
    "${review_json}" "${review_id}" "${expected_commit}" "${expected_login}" "update" >/dev/null
  [[ "$(jq -r '.body // ""' <<<"${review_json}")" == "${expected_body}" ]] ||
    fatal "review ${review_id} body does not match the update"
  printf '%s\n' "${review_json}"
}

confirm_created_review_by_match() {
  local repo="$1"
  local pr_number="$2"
  local expected_commit="$3"
  local expected_body="$4"
  local expected_login="$5"
  local reviews_json
  local matches_json
  local match_count
  local review_json
  local response_id

  reviews_json="$(
    gh api --paginate "repos/${repo}/pulls/${pr_number}/reviews" |
      jq -s 'if all(.[]; type == "array") then add else error("invalid review list response") end'
  )"
  matches_json="$(
    jq \
      --arg expected_commit "${expected_commit}" \
      --arg expected_body "${expected_body}" \
      --arg expected_login "${expected_login}" '
        [
          .[]
          | select(
              .commit_id == $expected_commit
              and .body == $expected_body
              and .user.login == $expected_login
            )
        ]
      ' <<<"${reviews_json}"
  )"
  match_count="$(jq 'length' <<<"${matches_json}")"
  [[ "${match_count}" -eq 1 ]] ||
    fatal "could not identify the created review after an invalid POST response (matching reviews: ${match_count})"

  review_json="$(jq -c '.[0]' <<<"${matches_json}")"
  response_id="$(jq -r '.id // empty' <<<"${review_json}")"
  validate_confirmed_review \
    "${review_json}" "${response_id}" "${expected_commit}" "${expected_login}" "creation"
}

confirm_created_review() {
  local repo="$1"
  local pr_number="$2"
  local response_file="$3"
  local expected_commit="$4"
  local expected_body="$5"
  local expected_login="$6"
  local response_id=""
  local review_json

  if response_id="$(
    jq -r '
      if type == "object"
        and (.id | type == "number" and . > 0 and floor == .)
      then (.id | tostring)
      else empty
      end
    ' "${response_file}" 2>/dev/null
  )"; then
    :
  else
    response_id=""
  fi

  if [[ -n "${response_id}" ]]; then
    review_json="$(gh api "repos/${repo}/pulls/${pr_number}/reviews/${response_id}")"
    validate_confirmed_review \
      "${review_json}" "${response_id}" "${expected_commit}" "${expected_login}" "creation" >/dev/null
    [[ "$(jq -r '.body // ""' <<<"${review_json}")" == "${expected_body}" ]] ||
      fatal "review ${response_id} body does not match the created review"
    printf '%s\n' "${review_json}"
    return
  fi

  confirm_created_review_by_match \
    "${repo}" "${pr_number}" "${expected_commit}" "${expected_body}" "${expected_login}"
}

report_confirmed_write_error() {
  local method="$1"
  local status="$2"
  local error_file="$3"

  printf '%s: WARNING: GitHub %s exited with status %s, but the pending review was confirmed.\n' \
    "${PROG}" "${method}" "${status}" >&2
  if [[ -s "${error_file}" ]]; then
    cat -- "${error_file}" >&2
  fi
}

fail_unknown_write() {
  local method="$1"
  local status="$2"
  local error_file="$3"
  local confirmation_error_file="$4"

  if [[ -s "${error_file}" ]]; then
    cat -- "${error_file}" >&2
  fi
  printf '%s: ERROR: GitHub %s exited with status %s; write outcome is unknown.\n' \
    "${PROG}" "${method}" "${status}" >&2
  if [[ -s "${confirmation_error_file}" ]]; then
    printf '%s: Confirmation error:\n' "${PROG}" >&2
    cat -- "${confirmation_error_file}" >&2
  fi
  exit "${status}"
}

emit_result() {
  local mode="$1"
  local review_json="$2"
  local inline_count="$3"
  local body_count="$4"
  local relocated_count="$5"

  jq -n \
    --arg mode "${mode}" \
    --argjson review_id "$(jq -r '.id' <<<"${review_json}")" \
    --arg state "$(jq -r '.state' <<<"${review_json}")" \
    --arg commit_id "$(jq -r '.commit_id' <<<"${review_json}")" \
    --argjson inline_comments_posted "${inline_count}" \
    --argjson body_findings_included "${body_count}" \
    --argjson relocated_findings "${relocated_count}" \
    '{mode:$mode, review_id:$review_id, state:$state, commit_id:$commit_id,
      inline_comments_posted:$inline_comments_posted,
      body_findings_included:$body_findings_included,
      relocated_findings:$relocated_findings}'
}

main() {
  local repo=""
  local pr_number=""
  local base_commit_id=""
  local commit_id=""
  local review_id="null"
  local inline_findings_file=""
  local non_inline_findings_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --repo | --pr-number | --base-commit-id | --commit-id | --review-id | --inline-findings | --non-inline-findings)
      [[ $# -ge 2 ]] || fatal "$1 requires an argument" 2
      case "$1" in
      --repo) repo="$2" ;;
      --pr-number) pr_number="$2" ;;
      --base-commit-id) base_commit_id="$2" ;;
      --commit-id) commit_id="$2" ;;
      --review-id) review_id="$2" ;;
      --inline-findings) inline_findings_file="$2" ;;
      --non-inline-findings) non_inline_findings_file="$2" ;;
      esac
      shift 2
      ;;
    --repo=*)
      repo="${1#*=}"
      shift
      ;;
    --pr-number=*)
      pr_number="${1#*=}"
      shift
      ;;
    --base-commit-id=*)
      base_commit_id="${1#*=}"
      shift
      ;;
    --commit-id=*)
      commit_id="${1#*=}"
      shift
      ;;
    --review-id=*)
      review_id="${1#*=}"
      shift
      ;;
    --inline-findings=*)
      inline_findings_file="${1#*=}"
      shift
      ;;
    --non-inline-findings=*)
      non_inline_findings_file="${1#*=}"
      shift
      ;;
    *) fatal "unknown argument: $1" 2 ;;
    esac
  done

  [[ -n "${repo}" ]] || fatal "--repo is required" 2
  [[ "${repo}" =~ ^[^/]+/[^/]+$ ]] || fatal "--repo must use OWNER/REPO format" 2
  [[ "${pr_number}" =~ ^[0-9]+$ ]] || fatal "--pr-number must be numeric" 2
  [[ -n "${base_commit_id}" ]] || fatal "--base-commit-id is required" 2
  [[ -n "${commit_id}" ]] || fatal "--commit-id is required" 2
  [[ "${review_id}" == "null" || "${review_id}" =~ ^[0-9]+$ ]] ||
    fatal "--review-id must be numeric or null" 2
  [[ -f "${inline_findings_file}" ]] ||
    fatal "inline findings file not found: ${inline_findings_file}" 2
  [[ -f "${non_inline_findings_file}" ]] ||
    fatal "non-inline findings file not found: ${non_inline_findings_file}" 2

  require_command date
  require_command cat
  require_command gh
  require_command jq
  require_command mktemp
  validate_findings "${inline_findings_file}" "${non_inline_findings_file}"

  local current_user_json
  local current_login
  current_user_json="$(gh api user)"
  jq -e '
    type == "object"
    and (.login | type == "string" and length > 0)
  ' <<<"${current_user_json}" >/dev/null ||
    fatal "current GitHub user response is invalid"
  current_login="$(jq -r '.login' <<<"${current_user_json}")"

  validate_current_pr "${repo}" "${pr_number}" "${base_commit_id}" "${commit_id}"

  local timestamp
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  tmp_dir="$(mktemp -d "/tmp/github-post-pr-review-${timestamp}-XXXXXX")"
  trap cleanup EXIT

  local files_json
  local positions
  local valid_inline="${tmp_dir}/valid-inline.json"
  local relocated="${tmp_dir}/relocated.json"
  local final_body_findings="${tmp_dir}/body-findings.json"
  local comments="${tmp_dir}/comments.json"
  local body_file="${tmp_dir}/body.md"
  local payload="${tmp_dir}/payload.json"
  local response="${tmp_dir}/response.json"
  local write_error="${tmp_dir}/write.stderr"
  local confirmation_error="${tmp_dir}/confirmation.stderr"
  files_json="$(
    gh api --paginate "repos/${repo}/pulls/${pr_number}/files" |
      jq -s 'add'
  )"
  positions="$(diff_position_index <<<"${files_json}")"

  jq --argjson positions "${positions}" '
    map(
      . as $finding
      | select(($positions[$finding.file] // []) | index($finding.line) != null)
    )
  ' "${inline_findings_file}" >"${valid_inline}"
  jq --argjson positions "${positions}" '
    map(
      . as $finding
      | select((($positions[$finding.file] // []) | index($finding.line)) == null)
      | {
          severity: (.severity // "important"),
          description: ("`" + .file + ":" + (.line | tostring) + "`: " + .description)
        }
    )
  ' "${inline_findings_file}" >"${relocated}"

  local existing_review_json=""
  if [[ "${review_id}" != "null" ]]; then
    existing_review_json="$(gh api "repos/${repo}/pulls/${pr_number}/reviews/${review_id}")"
    validate_owned_pending_review \
      "${existing_review_json}" "${review_id}" "${commit_id}" "${current_login}"

    jq -s '
      .[0]
      + (.[1] | map({
          severity: (.severity // "important"),
          description: ("`" + .file + ":" + (.line | tostring) + "`: " + .description)
        }))
    ' "${relocated}" "${valid_inline}" >"${relocated}.all"
    mv -- "${relocated}.all" "${relocated}"
    printf '[]\n' >"${valid_inline}"
  fi

  jq -s '.[0] + .[1]' "${non_inline_findings_file}" "${relocated}" \
    >"${final_body_findings}"
  jq '
    map({
      path: .file,
      line: .line,
      side: "RIGHT",
      body: ("**[" + (.severity // "important") + "]** " + .description)
    })
  ' "${valid_inline}" >"${comments}"
  jq -r '
    if length == 0 then ""
    else
      "## Additional findings\n\n"
      + (map("- **[" + (.severity // "important") + "]** " + .description) | join("\n"))
    end
  ' "${final_body_findings}" >"${body_file}"

  local inline_count
  local body_count
  local relocated_count
  local review_body
  local managed_section=""
  inline_count="$(jq 'length' "${comments}")"
  body_count="$(jq 'length' "${final_body_findings}")"
  relocated_count="$(jq 'length' "${relocated}")"
  review_body="$(<"${body_file}")"
  if [[ -n "${review_body}" ]]; then
    managed_section="${REVIEW_SECTION_START}
${review_body}
${REVIEW_SECTION_END}"
  fi

  if [[ "${inline_count}" -eq 0 && "${body_count}" -eq 0 ]]; then
    jq -n \
      --arg mode "nothing_to_post" \
      --argjson review_id "${review_id}" \
      --arg state "SKIPPED" \
      --argjson inline_comments_posted 0 \
      --argjson body_findings_included 0 \
      --argjson relocated_findings 0 \
      '{mode:$mode, review_id:$review_id, state:$state,
        inline_comments_posted:$inline_comments_posted,
        body_findings_included:$body_findings_included,
        relocated_findings:$relocated_findings}'
    exit 0
  fi

  if [[ "${review_id}" != "null" ]]; then
    local existing_body
    local updated_body
    local prefix
    local suffix
    local confirmed_review_json
    existing_review_json="$(gh api "repos/${repo}/pulls/${pr_number}/reviews/${review_id}")"
    validate_owned_pending_review \
      "${existing_review_json}" "${review_id}" "${commit_id}" "${current_login}"
    existing_body="$(jq -r '.body // ""' <<<"${existing_review_json}")"
    if [[ "${existing_body}" == *"${REVIEW_SECTION_START}"* &&
      "${existing_body}" == *"${REVIEW_SECTION_END}"* ]]; then
      prefix="${existing_body%%"${REVIEW_SECTION_START}"*}"
      suffix="${existing_body#*"${REVIEW_SECTION_END}"}"
      updated_body="${prefix}${managed_section}${suffix}"
    elif [[ -n "${managed_section}" ]]; then
      updated_body="${existing_body}

${managed_section}"
    else
      updated_body="${existing_body}"
    fi
    jq -n --arg body "${updated_body}" '{body:$body}' >"${payload}"
    validate_current_pr "${repo}" "${pr_number}" "${base_commit_id}" "${commit_id}"
    local write_status=0
    if gh api --method PUT "repos/${repo}/pulls/${pr_number}/reviews/${review_id}" \
      --input "${payload}" >"${response}" 2>"${write_error}"; then
      write_status=0
    else
      write_status=$?
    fi
    if [[ "${write_status}" -ne 0 ]]; then
      if confirmed_review_json="$(
        confirm_updated_review \
          "${repo}" "${pr_number}" "${review_id}" "${commit_id}" \
          "${updated_body}" "${current_login}" \
          2>"${confirmation_error}"
      )"; then
        report_confirmed_write_error "PUT" "${write_status}" "${write_error}"
      else
        fail_unknown_write \
          "PUT" "${write_status}" "${write_error}" "${confirmation_error}"
      fi
    elif review_response_is_valid \
      "${response}" "${review_id}" "${commit_id}" "${current_login}"; then
      confirmed_review_json="$(<"${response}")"
    else
      confirmed_review_json="$(
        confirm_updated_review \
          "${repo}" "${pr_number}" "${review_id}" "${commit_id}" \
          "${updated_body}" "${current_login}"
      )"
    fi
    emit_result \
      "updated_existing_pending" "${confirmed_review_json}" 0 \
      "${body_count}" "${relocated_count}"
    exit 0
  fi

  local complete_body="${REVIEW_MARKER}"
  if [[ -n "${managed_section}" ]]; then
    complete_body="${complete_body}

${managed_section}"
  fi
  jq -n \
    --arg commit_id "${commit_id}" \
    --arg body "${complete_body}" \
    --slurpfile comments "${comments}" \
    '{commit_id:$commit_id, body:$body, comments:$comments[0]}' >"${payload}"
  validate_current_pr "${repo}" "${pr_number}" "${base_commit_id}" "${commit_id}"
  local write_status=0
  if gh api --method POST "repos/${repo}/pulls/${pr_number}/reviews" \
    --input "${payload}" >"${response}" 2>"${write_error}"; then
    write_status=0
  else
    write_status=$?
  fi

  local confirmed_review_json
  if [[ "${write_status}" -ne 0 ]]; then
    if confirmed_review_json="$(
      confirm_created_review_by_match \
        "${repo}" "${pr_number}" "${commit_id}" "${complete_body}" "${current_login}" \
        2>"${confirmation_error}"
    )"; then
      report_confirmed_write_error "POST" "${write_status}" "${write_error}"
    else
      fail_unknown_write \
        "POST" "${write_status}" "${write_error}" "${confirmation_error}"
    fi
  elif review_response_is_valid "${response}" "" "${commit_id}" "${current_login}"; then
    confirmed_review_json="$(<"${response}")"
  else
    confirmed_review_json="$(
      confirm_created_review \
        "${repo}" "${pr_number}" "${response}" "${commit_id}" \
        "${complete_body}" "${current_login}"
    )"
  fi
  emit_result \
    "new" "${confirmed_review_json}" "${inline_count}" \
    "${body_count}" "${relocated_count}"
}

main "$@"
