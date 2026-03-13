#!/usr/bin/env bash
# Fetches unresolved review comments for the current PR

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
get-unresolved-comments.sh — Fetch unresolved review comments for the current PR.

Usage: get-unresolved-comments.sh

Outputs one JSON object per unresolved review thread (to stdout):
  path        File path the comment is on
  line        Line number
  body        Comment text
  isOutdated  Whether the comment is outdated

Exits with code 1 if no PR is found for the current branch.
EOF
  exit 0
fi

# Auto-detect repo and PR info
REPO_INFO=$(gh repo view --json owner,name --jq '{owner: .owner.login, name: .name}')
OWNER=$(echo "$REPO_INFO" | jq -r .owner)
REPO=$(echo "$REPO_INFO" | jq -r .name)
PR_NUMBER=$(gh pr list --head "$(git branch --show-current)" --json number --jq '.[0].number')

if [ -z "$PR_NUMBER" ]; then
  echo "Error: No PR found for current branch" >&2
  exit 1
fi

echo "Fetching unresolved comments for PR #$PR_NUMBER in $OWNER/$REPO..." >&2
echo "" >&2

# Fetch unresolved review comments
gh api graphql -f query="query {
  repository(owner: \"$OWNER\", name: \"$REPO\") {
    pullRequest(number: $PR_NUMBER) {
      reviewThreads(first: 20) {
        nodes {
          isResolved
          isOutdated
          comments(first: 1) {
            nodes {
              author {
                login
              }
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
      select(.isResolved == false) |
      {
        path: .comments.nodes[0].path,
        line: .comments.nodes[0].line,
        body: .comments.nodes[0].body,
        isOutdated
      }'
