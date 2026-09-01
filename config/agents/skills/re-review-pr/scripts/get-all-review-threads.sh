#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat <<EOF
Usage: ${PROG} [--owner OWNER] [--repo REPO] [--pr NUMBER]
Fetch all review threads as a JSON array.
EOF
}

fatal() {
  printf '%s: ERROR: %s\n' "${PROG}" "$1" >&2
  exit "${2:-1}"
}

main() {
  local owner="" repo="" pr_number=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --owner)
      [[ $# -ge 2 ]] || fatal "--owner requires an argument" 2
      owner="$2"
      shift 2
      ;;
    --repo)
      [[ $# -ge 2 ]] || fatal "--repo requires an argument" 2
      repo="$2"
      shift 2
      ;;
    --pr)
      [[ $# -ge 2 ]] || fatal "--pr requires an argument" 2
      pr_number="$2"
      shift 2
      ;;
    *) fatal "unknown argument: $1" 2 ;;
    esac
  done

  if [[ -z "${owner}" || -z "${repo}" ]]; then
    local repo_info
    repo_info="$(gh repo view --json owner,name)"
    [[ -n "${owner}" ]] || owner="$(jq -r '.owner.login' <<<"${repo_info}")"
    [[ -n "${repo}" ]] || repo="$(jq -r '.name' <<<"${repo_info}")"
  fi
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
              comments(first: 100) { totalCount nodes { author { login } body } }
            }
          }
        }
      }
    }' |
    jq -s '[.[].data.repository.pullRequest.reviewThreads.nodes[]
      | if .comments.totalCount > 100 then error("review thread has more than 100 comments") else . end
      | {
          id, path, line, isResolved, isOutdated,
          body: .comments.nodes[0].body,
          author: (.comments.nodes[0].author.login // null),
          comments: [.comments.nodes[] | {author: (.author.login // null), body}]
        }]'
}

main "$@"
