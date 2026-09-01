#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat <<'EOF'
Usage: pr-meta.sh [--pr-number NUMBER]
Print current pull request and pending-review metadata as JSON.

The result includes the exact base and head commit IDs, any pending review
owned by the authenticated user, and all existing review comments.
EOF
}

fatal() {
  local message="$1"
  local status="${2:-1}"

  printf '%s: ERROR: %s\n' "${PROG}" "${message}" >&2
  exit "${status}"
}

main() {
  local pr_number=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --pr-number)
      [[ $# -ge 2 ]] || fatal "--pr-number requires an argument" 2
      pr_number="$2"
      shift 2
      ;;
    --pr-number=*)
      pr_number="${1#*=}"
      shift
      ;;
    *) fatal "unknown argument: $1" 2 ;;
    esac
  done

  [[ -z "${pr_number}" || "${pr_number}" =~ ^[0-9]+$ ]] ||
    fatal "--pr-number must be numeric" 2

  local -a pr_command=(gh pr view)
  if [[ -n "${pr_number}" ]]; then
    pr_command+=("${pr_number}")
  fi
  pr_command+=(--json "number,baseRefName,baseRefOid,headRefOid")

  local pr_json
  local repo
  local current_user
  local reviews
  local pending_review
  local comments
  pr_json="$("${pr_command[@]}")"
  pr_number="$(jq -r '.number' <<<"${pr_json}")"
  repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
  current_user="$(gh api user --jq '.login')"
  reviews="$(gh api --paginate "repos/${repo}/pulls/${pr_number}/reviews" | jq -s 'add')"
  pending_review="$(
    jq --arg current_user "${current_user}" \
      'map(select(.state == "PENDING" and .user.login == $current_user))
       | first
       | if . == null then null else {id, commit_id} end' \
      <<<"${reviews}"
  )"
  comments="$(
    gh api --paginate "repos/${repo}/pulls/${pr_number}/comments" |
      jq -s 'add | map({path, line, side, body, commit_id})'
  )"

  jq -n \
    --argjson pr_number "${pr_number}" \
    --arg repo "${repo}" \
    --arg base_ref "$(jq -r '.baseRefName' <<<"${pr_json}")" \
    --arg base_commit_id "$(jq -r '.baseRefOid' <<<"${pr_json}")" \
    --arg commit_id "$(jq -r '.headRefOid' <<<"${pr_json}")" \
    --argjson pending_review "${pending_review}" \
    --argjson comments "${comments}" \
    '{
      pr_number: $pr_number,
      repo: $repo,
      base_ref: $base_ref,
      base_commit_id: $base_commit_id,
      commit_id: $commit_id,
      review_id: ($pending_review.id // null),
      review_commit_id: ($pending_review.commit_id // null),
      comments: $comments
    }'
}

main "$@"
