#!/usr/bin/env bash
# Sets up a git worktree for an existing branch, ensuring it is up to date.
# Usage: setup-worktree.sh --branch <branch>

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
setup-worktree.sh — Create or update a git worktree for an existing branch.

Usage: setup-worktree.sh --branch <branch>

Flags:
  --branch NAME  Branch to check out in the worktree (required)

Output (stdout): absolute path to the worktree directory

The worktree is created at .worktrees/<branch> relative to the repository root.
If it already exists, it is reset to the latest remote state.
Exits with code 1 if --branch is not provided.
EOF
  exit 0
fi

BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    *) echo "error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$BRANCH" ]]; then
  echo "error: --branch is required" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_PATH="$REPO_ROOT/.worktrees/$BRANCH"

echo "Fetching latest '$BRANCH' from origin..." >&2
git fetch origin "$BRANCH"

if [[ ! -d "$WORKTREE_PATH" ]]; then
  echo "Creating worktree at $WORKTREE_PATH..." >&2
  git worktree add "$WORKTREE_PATH" "$BRANCH" 2>/dev/null \
    || git worktree add --track -b "$BRANCH" "$WORKTREE_PATH" "origin/$BRANCH"
fi

echo "Resetting to origin/$BRANCH..." >&2
git -C "$WORKTREE_PATH" reset --hard "origin/$BRANCH"

echo "$WORKTREE_PATH"
