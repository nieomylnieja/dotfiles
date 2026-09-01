#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat <<EOF
Usage: ${PROG} [--pr NUMBER]
Fetch all pull request review threads as a JSON array.

Options:
      --pr NUMBER  pull request number (default: current branch PR)
  -h, --help       display this help and exit
EOF
}

fatal() {
  printf '%s: ERROR: %s\n' "${PROG}" "$1" >&2
  exit "${2:-1}"
}

main() {
  local pr_number=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --pr)
      [[ $# -ge 2 ]] || fatal "--pr requires an argument" 2
      pr_number="$2"
      shift 2
      ;;
    *) fatal "unknown argument: $1" 2 ;;
    esac
  done

  local repo_info owner repo
  repo_info="$(gh repo view --json owner,name)"
  owner="$(jq -r '.owner.login' <<<"${repo_info}")"
  repo="$(jq -r '.name' <<<"${repo_info}")"
  [[ -n "${pr_number}" ]] || pr_number="$(gh pr view --json number --jq '.number')"

  gh api graphql --paginate \
    -f owner="${owner}" -f repo="${repo}" -F pr="${pr_number}" \
    -f query='query($owner: String!, $repo: String!, $pr: Int!, $endCursor: String) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $pr) {
          reviewThreads(first: 100, after: $endCursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id isResolved isOutdated path line
              resolvedBy { login }
              comments(first: 100) {
                totalCount
                nodes { author { login } body createdAt }
              }
            }
          }
        }
      }
    }' |
    jq -s '[.[].data.repository.pullRequest.reviewThreads.nodes[]
      | if .comments.totalCount > 100 then error("review thread has more than 100 comments") else . end
      | {
          id, path, line, isResolved, isOutdated,
          resolvedBy: (.resolvedBy.login // null),
          comments: [.comments.nodes[] | {author: (.author.login // null), body, createdAt}]
        }]'
}

main "$@"
