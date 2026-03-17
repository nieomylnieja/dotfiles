#!/usr/bin/env bash
# Finds the most recent local review file for the current branch.
# Usage: REVIEW_FILE=$(find-review-file.sh)
#
# Output: absolute path to the most recent review JSON file, or exits 1 if none found.

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
find-review-file.sh — Find the most recent local PR review file for the current branch.

Usage: REVIEW_FILE=$(find-review-file.sh)

Output: absolute path to the most recent review JSON file.

Exits with code 1 if no review file is found for the current branch.
EOF
  exit 0
fi

REPO_SLUG=$(gh repo view --json nameWithOwner -q '.nameWithOwner' | tr '/' '-')
REVIEW_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/agents/pr-review/$REPO_SLUG"
BRANCH_SLUG=$(git rev-parse --abbrev-ref HEAD | tr '/' '-' | tr -cd '[:alnum:]-_')
REVIEW_FILE=$(ls -t "$REVIEW_DIR"/*_${BRANCH_SLUG}.json 2>/dev/null | head -1 || true)

if [[ -z "$REVIEW_FILE" ]]; then
  echo "error: no review file found for branch '$BRANCH_SLUG' in $REVIEW_DIR" >&2
  exit 1
fi

echo "$REVIEW_FILE"
