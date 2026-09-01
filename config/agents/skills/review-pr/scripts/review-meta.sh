#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat <<'EOF'
Usage: review-meta.sh --pr-number NUMBER
Create the local review output directory and print exact PR metadata as JSON.
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

  umask 077

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

  [[ "${pr_number}" =~ ^[0-9]+$ ]] || fatal "--pr-number must be numeric" 2

  local pr_json
  local repo
  local repo_slug
  local branch
  local branch_slug
  local timestamp
  local review_dir
  local outfile
  pr_json="$(
    gh pr view "${pr_number}" \
      --json number,baseRefName,baseRefOid,headRefName,headRefOid
  )"
  repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
  repo_slug="${repo//\//-}"
  branch="$(jq -r '.headRefName' <<<"${pr_json}")"
  branch_slug="$(printf '%s' "${branch//\//-}" | tr -cd '[:alnum:]-_')"
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  review_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/agents/pr-review/${repo_slug}"
  mkdir -p -- "${review_dir}"
  chmod 700 -- "${review_dir}"
  outfile="$(
    mktemp --suffix=.json \
      "${review_dir}/${timestamp}_${branch_slug}_XXXXXX"
  )"
  chmod 600 -- "${outfile}"

  jq -n \
    --arg outfile "${outfile}" \
    --arg repo "${repo}" \
    --arg branch "${branch}" \
    --arg base_ref "$(jq -r '.baseRefName' <<<"${pr_json}")" \
    --arg base_commit_id "$(jq -r '.baseRefOid' <<<"${pr_json}")" \
    --arg commit_id "$(jq -r '.headRefOid' <<<"${pr_json}")" \
    --argjson pr_number "${pr_number}" \
    '{
      outfile: $outfile,
      repo: $repo,
      branch: $branch,
      base_ref: $base_ref,
      base_commit_id: $base_commit_id,
      commit_id: $commit_id,
      pr_number: $pr_number
    }'
}

main "$@"
