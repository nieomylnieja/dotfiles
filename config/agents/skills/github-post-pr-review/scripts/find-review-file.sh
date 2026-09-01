#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat <<'EOF'
Usage: find-review-file.sh [--branch BRANCH]
Print the newest valid local review for the repository and branch.
EOF
}

fatal() {
  printf '%s: ERROR: %s\n' "${PROG}" "$1" >&2
  exit "${2:-1}"
}

main() {
  local branch=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --branch)
      [[ $# -ge 2 ]] || fatal "--branch requires an argument" 2
      branch="$2"
      shift 2
      ;;
    --branch=*)
      branch="${1#*=}"
      shift
      ;;
    *) fatal "unknown argument: $1" 2 ;;
    esac
  done

  local repo
  local repo_slug
  local review_dir
  repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
  [[ -n "${branch}" ]] || branch="$(git branch --show-current)"
  [[ -n "${branch}" ]] || fatal "detached HEAD requires --branch" 2

  repo_slug="${repo//\//-}"
  review_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/agents/pr-review/${repo_slug}"
  [[ -d "${review_dir}" ]] ||
    fatal "no review directory for ${repo}: ${review_dir}"

  local newest=""
  local newest_mtime=-1
  local candidate
  local candidate_mtime
  shopt -s nullglob
  for candidate in "${review_dir}"/*.json; do
    if ! jq -e \
      --arg repo "${repo}" \
      --arg branch "${branch}" \
      'type == "object"
       and .version == 1
       and .repo == $repo
       and .branch == $branch
       and (.timestamp | type == "string" and length > 0)
       and (.base_ref | type == "string" and length > 0)
       and (.base_commit_id | type == "string" and length > 0)
       and (.commit_id | type == "string" and length > 0)
       and (.pr_number | type == "number" and floor == . and . > 0)
       and (.aspects | type == "array" and all(.[]; type == "string"))
       and (.findings | type == "array")' \
      "${candidate}" >/dev/null 2>&1; then
      continue
    fi

    candidate_mtime="$(stat -c '%Y' "${candidate}")"
    if ((candidate_mtime > newest_mtime)) ||
      { ((candidate_mtime == newest_mtime)) && [[ "${candidate}" > "${newest}" ]]; }; then
      newest="${candidate}"
      newest_mtime="${candidate_mtime}"
    fi
  done

  [[ -n "${newest}" ]] ||
    fatal "no valid review found for ${repo} branch '${branch}' in ${review_dir}"
  printf '%s\n' "${newest}"
}

main "$@"
