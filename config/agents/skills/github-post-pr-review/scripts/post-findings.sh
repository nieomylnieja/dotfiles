#!/usr/bin/env bash

set -euo pipefail

readonly PROG="${0##*/}"
readonly REVIEW_MARKER="<!-- github-post-pr-review -->"
readonly REVIEW_SECTION_START="<!-- github-post-pr-review:non-inline:start -->"
readonly REVIEW_SECTION_END="<!-- github-post-pr-review:non-inline:end -->"
tmp_dir=""
tmp_comments=""
tmp_body=""
tmp_payload=""
tmp_response=""

usage() {
  cat << EOF
Usage: ${PROG} [OPTION]...
Post PR review findings to GitHub as a pending review.

Options:
  --repo OWNER/REPO            repository slug (required)
  --pr-number NUMBER           pull request number (required)
  --commit-id SHA              commit SHA for review creation (required)
  --review-id ID|null          existing pending review ID, or null
  --inline-findings FILE       JSON array of inline findings (required)
  --non-inline-findings FILE   JSON array of non-inline findings (required)
  -h, --help                   display this help and exit

Exit status:
  0  success
  1  general error
  2  usage error
EOF
}

fatal() {
  echo "${PROG}: ERROR: $*" >&2
  exit "${2:-1}"
}

require_command() {
  command -v "$1" > /dev/null 2>&1 || fatal "required command not found: $1"
}

validate_json_array() {
  local file
  file="$1"

  jq -e 'type == "array"' "${file}" > /dev/null || fatal "invalid JSON array file: ${file}" 2
}

validate_inline_findings() {
  local file
  file="$1"

  jq -e '
    all(
      .[];
      (.file | type == "string" and length > 0)
      and (.line | type == "number")
      and (.description | type == "string" and length > 0)
    )
  ' "${file}" > /dev/null || fatal "inline findings contain invalid entries: ${file}" 2
}

validate_non_inline_findings() {
  local file
  file="$1"

  jq -e '
    all(
      .[];
      (.description | type == "string" and length > 0)
    )
  ' "${file}" > /dev/null || fatal "non-inline findings contain invalid entries: ${file}" 2
}

cleanup() {
  rm -f "${tmp_comments:-}" "${tmp_body:-}" "${tmp_payload:-}" "${tmp_response:-}"
  rm -rf "${tmp_dir:-}"
}

main() {
  local repo=""
  local pr_number=""
  local commit_id=""
  local review_id="null"
  local inline_findings_file=""
  local non_inline_findings_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        [[ $# -lt 2 ]] && fatal "--repo requires an argument" 2
        repo="$2"
        shift 2
        ;;
      --repo=*)
        repo="${1#*=}"
        shift
        ;;
      --pr-number)
        [[ $# -lt 2 ]] && fatal "--pr-number requires an argument" 2
        pr_number="$2"
        shift 2
        ;;
      --pr-number=*)
        pr_number="${1#*=}"
        shift
        ;;
      --commit-id)
        [[ $# -lt 2 ]] && fatal "--commit-id requires an argument" 2
        commit_id="$2"
        shift 2
        ;;
      --commit-id=*)
        commit_id="${1#*=}"
        shift
        ;;
      --review-id)
        [[ $# -lt 2 ]] && fatal "--review-id requires an argument" 2
        review_id="$2"
        shift 2
        ;;
      --review-id=*)
        review_id="${1#*=}"
        shift
        ;;
      --inline-findings)
        [[ $# -lt 2 ]] && fatal "--inline-findings requires an argument" 2
        inline_findings_file="$2"
        shift 2
        ;;
      --inline-findings=*)
        inline_findings_file="${1#*=}"
        shift
        ;;
      --non-inline-findings)
        [[ $# -lt 2 ]] && fatal "--non-inline-findings requires an argument" 2
        non_inline_findings_file="$2"
        shift 2
        ;;
      --non-inline-findings=*)
        non_inline_findings_file="${1#*=}"
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        fatal "unknown option: $1" 2
        ;;
      *)
        fatal "unexpected argument: $1" 2
        ;;
    esac
  done

  [[ -z "${repo}" ]] && fatal "--repo is required" 2
  [[ -z "${pr_number}" ]] && fatal "--pr-number is required" 2
  [[ -z "${commit_id}" ]] && fatal "--commit-id is required" 2
  [[ -z "${inline_findings_file}" ]] && fatal "--inline-findings is required" 2
  [[ -z "${non_inline_findings_file}" ]] && fatal "--non-inline-findings is required" 2

  [[ -f "${inline_findings_file}" ]] || fatal "inline findings file not found: ${inline_findings_file}" 2
  [[ -f "${non_inline_findings_file}" ]] || fatal "non-inline findings file not found: ${non_inline_findings_file}" 2

  [[ "${pr_number}" =~ ^[0-9]+$ ]] || fatal "--pr-number must be numeric" 2
  if [[ "${review_id}" != "null" && ! "${review_id}" =~ ^[0-9]+$ ]]; then
    fatal "--review-id must be numeric or null" 2
  fi

  require_command gh
  require_command jq
  require_command mktemp
  require_command date

  validate_json_array "${inline_findings_file}"
  validate_json_array "${non_inline_findings_file}"
  validate_inline_findings "${inline_findings_file}"
  validate_non_inline_findings "${non_inline_findings_file}"

  local timestamp
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  tmp_dir="$(mktemp -d "/tmp/github-post-pr-review-${timestamp}-XXXXXX")"
  tmp_comments="${tmp_dir}/inline-comments.json"
  tmp_body="${tmp_dir}/review-body.md"
  tmp_payload="${tmp_dir}/payload.json"
  tmp_response="${tmp_dir}/response.json"

  trap cleanup EXIT

  jq '
    map(
      {
        path: .file,
        line: .line,
        side: "RIGHT",
        body: "**[" + (.severity // "important") + "]** " + .description
      }
    )
  ' "${inline_findings_file}" > "${tmp_comments}"

  jq -r '
    if length == 0 then
      ""
    else
      "## Additional findings\n\n"
      + (map("- **[" + (.severity // "important") + "]** " + .description) | join("\n"))
    end
  ' "${non_inline_findings_file}" > "${tmp_body}"

  local inline_count
  local non_inline_count
  local review_body
  local review_body_with_marker
  local managed_non_inline_section

  inline_count="$(jq -r 'length' "${tmp_comments}")"
  non_inline_count="$(jq -r 'length' "${non_inline_findings_file}")"
  review_body="$(< "${tmp_body}")"
  if [[ -n "${review_body}" ]]; then
    managed_non_inline_section="${REVIEW_SECTION_START}
${review_body}
${REVIEW_SECTION_END}"
  else
    managed_non_inline_section=""
  fi

  if [[ -n "${review_body}" ]]; then
    review_body_with_marker="${REVIEW_MARKER}

${managed_non_inline_section}"
  else
    review_body_with_marker="${REVIEW_MARKER}"
  fi

  if [[ "${inline_count}" -eq 0 && "${non_inline_count}" -eq 0 ]]; then
    jq -n \
      --arg mode "nothing_to_post" \
      --argjson review_id "${review_id}" \
      --arg state "SKIPPED" \
      --argjson inline_comments_posted 0 \
      --argjson inline_comments_total 0 \
      --argjson non_inline_findings_included 0 \
      --argjson non_inline_findings_skipped 0 \
      '{
        mode: $mode,
        review_id: $review_id,
        state: $state,
        inline_comments_posted: $inline_comments_posted,
        inline_comments_total: $inline_comments_total,
        non_inline_findings_included: $non_inline_findings_included,
        non_inline_findings_skipped: $non_inline_findings_skipped
      }'
    exit 0
  fi

  if [[ "${review_id}" != "null" ]]; then
    local mode
    local non_inline_included
    local non_inline_skipped
    mode="blocked_existing_pending"
    non_inline_included=0
    non_inline_skipped="${non_inline_count}"

    if [[ "${non_inline_count}" -gt 0 ]]; then
      local existing_review_body
      local updated_review_body
      local prefix
      local suffix
      existing_review_body="$(gh api "repos/${repo}/pulls/${pr_number}/reviews/${review_id}" --jq '.body // ""')"

      if [[ "${existing_review_body}" != *"${REVIEW_MARKER}"* ]]; then
        jq -n \
          --arg mode "blocked_existing_pending" \
          --argjson review_id "${review_id}" \
          --arg state "PENDING" \
          --argjson inline_comments_posted 0 \
          --argjson inline_comments_total "${inline_count}" \
          --argjson non_inline_findings_included 0 \
          --argjson non_inline_findings_skipped "${non_inline_count}" \
          '{
            mode: $mode,
            review_id: $review_id,
            state: $state,
            inline_comments_posted: $inline_comments_posted,
            inline_comments_total: $inline_comments_total,
            non_inline_findings_included: $non_inline_findings_included,
            non_inline_findings_skipped: $non_inline_findings_skipped
          }'
        exit 0
      fi

      if [[ "${existing_review_body}" == *"${REVIEW_SECTION_START}"* && "${existing_review_body}" == *"${REVIEW_SECTION_END}"* ]]; then
        prefix="${existing_review_body%%"${REVIEW_SECTION_START}"*}"
        suffix="${existing_review_body#*"${REVIEW_SECTION_END}"}"
        updated_review_body="${prefix}${managed_non_inline_section}${suffix}"
      elif [[ -n "${existing_review_body}" ]]; then
        updated_review_body="${existing_review_body}

${managed_non_inline_section}"
      else
        updated_review_body="${REVIEW_MARKER}

${managed_non_inline_section}"
      fi

      jq -n --arg body "${updated_review_body}" '{ body: $body }' > "${tmp_payload}"
      gh api --method PUT "repos/${repo}/pulls/${pr_number}/reviews/${review_id}" --input "${tmp_payload}" > "${tmp_response}"

      mode="updated_existing_pending"
      non_inline_included="${non_inline_count}"
      non_inline_skipped=0
    fi

    jq -n \
      --arg mode "${mode}" \
      --argjson review_id "${review_id}" \
      --arg state "PENDING" \
      --argjson inline_comments_posted 0 \
      --argjson inline_comments_total "${inline_count}" \
      --argjson non_inline_findings_included "${non_inline_included}" \
      --argjson non_inline_findings_skipped "${non_inline_skipped}" \
      '{
        mode: $mode,
        review_id: $review_id,
        state: $state,
        inline_comments_posted: $inline_comments_posted,
        inline_comments_total: $inline_comments_total,
        non_inline_findings_included: $non_inline_findings_included,
        non_inline_findings_skipped: $non_inline_findings_skipped
      }'
    exit 0
  fi

  jq -n \
    --arg commit_id "${commit_id}" \
    --arg body "${review_body_with_marker}" \
    --slurpfile comments "${tmp_comments}" \
    '{
      commit_id: $commit_id,
      body: $body,
      comments: $comments[0]
    }' > "${tmp_payload}"

  gh api --method POST "repos/${repo}/pulls/${pr_number}/reviews" --input "${tmp_payload}" > "${tmp_response}"

  local created_review_id
  local state
  created_review_id="$(jq -r '.id' "${tmp_response}")"
  state="$(jq -r '.state' "${tmp_response}")"

  jq -n \
    --arg mode "new" \
    --argjson review_id "${created_review_id}" \
    --arg state "${state}" \
    --argjson inline_comments_posted "${inline_count}" \
    --argjson inline_comments_total "${inline_count}" \
    --argjson non_inline_findings_included "${non_inline_count}" \
    --argjson non_inline_findings_skipped 0 \
    '{
      mode: $mode,
      review_id: $review_id,
      state: $state,
      inline_comments_posted: $inline_comments_posted,
      inline_comments_total: $inline_comments_total,
      non_inline_findings_included: $non_inline_findings_included,
      non_inline_findings_skipped: $non_inline_findings_skipped
    }'
}

main "$@"
