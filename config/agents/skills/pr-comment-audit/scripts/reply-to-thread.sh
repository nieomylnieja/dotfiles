#!/usr/bin/env bash
# Reply to a PR review thread by its GraphQL node ID.

set -euo pipefail

usage() {
  cat <<'EOF'
reply-to-thread.sh — Reply to a review thread.

Usage: reply-to-thread.sh --id THREAD_ID --body "Reply text"

Options:
  --id ID       GraphQL node ID of the thread
  --body TEXT   Reply text (supports markdown)
  --help        Show this help

Outputs the created comment as JSON.
EOF
  exit 0
}

THREAD_ID=""
BODY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id)
      THREAD_ID="$2"
      shift 2
      ;;
    --body)
      BODY="$2"
      shift 2
      ;;
    --help) usage ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${THREAD_ID}" ]] || [[ -z "${BODY}" ]]; then
  echo "Error: both --id and --body are required" >&2
  exit 1
fi

gh api graphql -f query='
mutation($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: $threadId,
    body: $body
  }) {
    comment {
      id
      body
      author { login }
    }
  }
}' -f threadId="${THREAD_ID}" -f body="${BODY}" \
  --jq '.data.addPullRequestReviewThreadReply.comment | {id, body, author: .author.login}'
