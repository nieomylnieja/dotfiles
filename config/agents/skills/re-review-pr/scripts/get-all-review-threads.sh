#!/usr/bin/env bash
# Fetches all review threads for the current PR, both resolved and unresolved.
# Usage: get-all-review-threads.sh [--owner OWNER] [--repo REPO] [--pr PR_NUMBER]

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
get-all-review-threads.sh — Fetch all review threads for a PR.

Usage: get-all-review-threads.sh [--owner OWNER] [--repo REPO] [--pr PR_NUMBER]

Flags:
  --owner OWNER      GitHub repository owner (default: detected from current repo)
  --repo REPO        GitHub repository name (default: detected from current repo)
  --pr PR_NUMBER     Pull request number (default: detected from current branch)

All flags are optional; omitted values are auto-detected.

Outputs one JSON object per review thread (to stdout):
  path        File path the comment is on
  line        Line number
  body        First comment text (thread anchor)
  author      Login of the first comment author
  isResolved  Whether the thread is resolved
  isOutdated  Whether the comment is outdated
  comments    Array of {author, body} for all comments in the thread

Exits with code 1 if no PR is found for the current branch.
EOF
  exit 0
fi

OWNER=""
REPO=""
PR_NUMBER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)    OWNER="$2";     shift 2 ;;
    --repo)     REPO="$2";      shift 2 ;;
    --pr)       PR_NUMBER="$2"; shift 2 ;;
    *) echo "error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$OWNER" || -z "$REPO" || -z "$PR_NUMBER" ]]; then
  REPO_INFO=$(gh repo view --json owner,name --jq '{owner: .owner.login, name: .name}')
  [[ -z "$OWNER" ]]     && OWNER=$(echo "$REPO_INFO" | jq -r .owner)
  [[ -z "$REPO" ]]      && REPO=$(echo "$REPO_INFO" | jq -r .name)
  [[ -z "$PR_NUMBER" ]] && PR_NUMBER=$(gh pr list --head "$(git branch --show-current)" --json number --jq '.[0].number')

  if [[ -z "$PR_NUMBER" ]]; then
    echo "error: no PR found for current branch" >&2
    exit 1
  fi
fi

gh api graphql -f query="query {
  repository(owner: \"$OWNER\", name: \"$REPO\") {
    pullRequest(number: $PR_NUMBER) {
      reviewThreads(first: 50) {
        nodes {
          isResolved
          isOutdated
          comments(first: 20) {
            nodes {
              author { login }
              body
              path
              line
            }
          }
        }
      }
    }
  }
}" \
  --jq '
    .data.repository.pullRequest.reviewThreads.nodes[] |
    {
      path:       .comments.nodes[0].path,
      line:       .comments.nodes[0].line,
      body:       .comments.nodes[0].body,
      author:     .comments.nodes[0].author.login,
      isResolved,
      isOutdated,
      comments:   [.comments.nodes[] | {author: .author.login, body}]
    }'
