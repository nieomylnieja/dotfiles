#!/usr/bin/env bash
# Prepares the review output directory and prints shell variable assignments:
#   OUTFILE, REPO, BRANCH, COMMIT_ID, PR_NUMBER
# Usage: eval "$(bash scripts/review-meta.sh)"

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
review-meta.sh — Prepare the review output directory and print shell variable assignments.

Usage: eval "$(bash scripts/review-meta.sh)"

Output variables:
  OUTFILE     Full path to the timestamped JSON file to write
  REPO        Repository in owner/repo format
  BRANCH      Current git branch name
  COMMIT_ID   HEAD commit SHA
  PR_NUMBER   Pull request number, or empty if no PR exists

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
PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null || echo "")
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)

REVIEW_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/agents/pr-review/$REPO_SLUG"
mkdir -p "$REVIEW_DIR"

OUTFILE="$REVIEW_DIR/${TIMESTAMP}_${BRANCH_SLUG}.json"

printf 'OUTFILE=%s\nREPO=%s\nBRANCH=%s\nCOMMIT_ID=%s\nPR_NUMBER=%s\n' \
  "$OUTFILE" "$REPO" "$BRANCH" "$COMMIT_ID" "${PR_NUMBER:-}"
