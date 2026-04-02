#!/usr/bin/env bash
# Fetches all review threads for a PR with full comment chains and resolution status.

set -euo pipefail

usage() {
  cat <<'EOF'
fetch-threads.sh — Fetch all review threads for a PR.

Usage: fetch-threads.sh [--pr NUMBER]

Options:
  --pr NUMBER   PR number (default: auto-detect from current branch)
  --help        Show this help

Outputs JSON array of review threads to stdout:
  id            GraphQL node ID (needed for resolve/unresolve mutations)
  path          File path
  line          Line number (null if unavailable)
  isResolved    Whether the thread is currently resolved
  isOutdated    Whether the diff context is outdated
  resolvedBy    Login of user who resolved (null if unresolved)
  comments      Array of {author, body, createdAt} for all comments in thread

Exits with code 1 if no PR is found.
EOF
  exit 0
}

PR_NUMBER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)
      PR_NUMBER="$2"
      shift 2
      ;;
    --help) usage ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

REPO_INFO=$(gh repo view --json owner,name --jq '{owner: .owner.login, name: .name}')
OWNER=$(echo "${REPO_INFO}" | jq -r .owner)
REPO=$(echo "${REPO_INFO}" | jq -r .name)

if [[ -z "${PR_NUMBER}" ]]; then
  PR_NUMBER=$(gh pr list --head "$(git branch --show-current)" --json number --jq '.[0].number')
fi

if [[ -z "${PR_NUMBER}" ]]; then
  echo "Error: No PR found for current branch" >&2
  exit 1
fi

echo "Fetching review threads for PR #${PR_NUMBER} in ${OWNER}/${REPO}..." >&2

gh api graphql -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          resolvedBy { login }
          path
          line
          comments(first: 50) {
            nodes {
              author { login }
              body
              createdAt
            }
          }
        }
      }
    }
  }
}' -f owner="${OWNER}" -f repo="${REPO}" -F pr="${PR_NUMBER}" \
  --jq '[
    .data.repository.pullRequest.reviewThreads.nodes[] |
    {
      id,
      path,
      line,
      isResolved,
      isOutdated,
      resolvedBy: (.resolvedBy // {login: null}).login,
      comments: [.comments.nodes[] | {author: .author.login, body, createdAt}]
    }
  ]'
