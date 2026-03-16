#!/usr/bin/env bash
# Prepares the review output directory and prints JSON metadata:
#   outfile, repo, branch, commit_id, pr_number
# Usage: review_meta=$(bash scripts/review-meta.sh)

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
review-meta.sh — Prepare the review output directory and print JSON metadata.

Usage: review_meta=$(bash scripts/review-meta.sh)

Output fields (JSON):
  outfile     Full path to the timestamped JSON file to write
  repo        Repository in owner/repo format
  branch      Current git branch name
  commit_id   HEAD commit SHA
  pr_number   Pull request number, or null if no PR exists

The output directory ($XDG_DATA_HOME/agents/pr-review/<repo-slug>/) is
created automatically.
EOF
  exit 0
fi

REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
REPO_SLUG=$(echo "$REPO" | tr '/' '-')
BRANCH=$(git rev-parse --abbrev-ref HEAD)
BRANCH_SLUG=$(echo "$BRANCH" | tr '/' '-' | tr -cd '[:alnum:]-_')
COMMIT_ID=$(git rev-parse HEAD)
PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null || echo "null")
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)

REVIEW_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/agents/pr-review/$REPO_SLUG"
mkdir -p "$REVIEW_DIR"

OUTFILE="$REVIEW_DIR/${TIMESTAMP}_${BRANCH_SLUG}.json"

jq -n \
  --arg outfile "$OUTFILE" \
  --arg repo "$REPO" \
  --arg branch "$BRANCH" \
  --arg commit_id "$COMMIT_ID" \
  --argjson pr_number "$PR_NUMBER" \
  '{outfile: $outfile, repo: $repo, branch: $branch, commit_id: $commit_id, pr_number: $pr_number}'
