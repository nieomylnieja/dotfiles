#!/usr/bin/env bash
# Prints PR metadata as shell variable assignments.
# Usage: eval "$(pr-meta.sh)" or source <(pr-meta.sh)
#
# Output variables: PR_NUMBER, COMMIT_ID, REPO, REVIEW_ID
# REVIEW_ID is empty when no pending review exists.
# Exits with code 1 and prints an error if no PR exists for the current branch.

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
pr-meta.sh — Print PR metadata as shell variable assignments.

Usage: eval "$(pr-meta.sh)"

Output variables:
  PR_NUMBER   Pull request number
  COMMIT_ID   HEAD commit SHA of the PR branch
  REPO        Repository in owner/repo format
  REVIEW_ID   ID of an existing pending review, or empty if none

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
  jq -r 'map(select(.state=="PENDING")) | first | (.id | tostring) // ""' ||
  echo "")

printf 'PR_NUMBER=%s\nCOMMIT_ID=%s\nREPO=%s\nREVIEW_ID=%s\n' "$N" "$C" "$R" "$RID"
