#!/usr/bin/env bash
# Prints PR metadata as JSON.
# Usage: pr_meta=$(pr-meta.sh)
#
# Output fields: pr_number, commit_id, repo, review_id
# review_id is null when no pending review exists.
# Exits with code 1 and prints an error if no PR exists for the current branch.

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
pr-meta.sh — Print PR metadata as JSON.

Usage: pr_meta=$(pr-meta.sh)

Output fields:
  pr_number   Pull request number
  commit_id   HEAD commit SHA of the PR branch
  repo        Repository in owner/repo format
  review_id   ID of an existing pending review, or null if none

Exits with code 1 if no pull request exists for the current branch.
EOF
  exit 0
fi

if ! PR=$(gh pr view --json number,headRefOid 2>/dev/null); then
  echo "error: no pull request found for the current branch" >&2
  exit 1
fi

N=$(echo "$PR" | jq -r '.number')
C=$(echo "$PR" | jq -r '.headRefOid')
R=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
RID=$(gh api "repos/$R/pulls/$N/reviews" 2>/dev/null |
  jq 'map(select(.state=="PENDING")) | first | .id // null' ||
  echo "null")

jq -n --argjson pr_number "$N" --arg commit_id "$C" --arg repo "$R" --argjson review_id "$RID" \
  '{ pr_number: $pr_number, commit_id: $commit_id, repo: $repo, review_id: $review_id }'
