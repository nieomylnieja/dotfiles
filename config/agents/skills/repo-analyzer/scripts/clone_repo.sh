#!/usr/bin/env bash
set -euo pipefail

# Repository Cloner for repo-analyzer skill
# Clones or updates a git repository to XDG-compliant location
#
# Usage: clone_repo.sh --url <repo_url> [--branch <branch>]
# Example: clone_repo.sh --url https://github.com/user/repo --branch main

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
clone_repo.sh — Clone or update a git repository to an XDG-compliant location.

Usage: clone_repo.sh --url <repo_url> [--branch <branch>]

Flags:
  --url URL      Full URL (https:// or git@) or short owner/repo form (assumes GitHub)
  --branch NAME  Optional branch to check out after cloning

Output (stdout): absolute path to the cloned repository directory

Examples:
  clone_repo.sh --url https://github.com/user/repo --branch main
  clone_repo.sh --url git@github.com:user/repo.git
  clone_repo.sh --url user/repo

Repositories are stored under $XDG_DATA_HOME/claude/repositories/<platform>/<org>/<repo>.
If the repository already exists it is updated in place.
EOF
  exit 0
fi

REPO_URL=""
BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)    REPO_URL="$2"; shift 2 ;;
    --branch) BRANCH="$2";   shift 2 ;;
    *) echo "error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$REPO_URL" ]]; then
  echo "error: --url is required" >&2
  echo "Usage: $0 --url <repo_url> [--branch <branch>]" >&2
  exit 1
fi

# Parse repository URL to extract platform, org, and repo name
parse_repo_url() {
  local url="$1"

  # Handle short form (owner/repo assumes GitHub)
  if [[ ! "$url" =~ (https?://|git@) ]]; then
    PLATFORM="github.com"
    ORG=$(echo "$url" | cut -d'/' -f1)
    REPO=$(echo "$url" | cut -d'/' -f2 | sed 's/\.git$//')
    return
  fi

  # Extract platform
  if [[ "$url" =~ git@ ]]; then
    # SSH format: git@platform:owner/repo.git
    PLATFORM=$(echo "$url" | sed -E 's|git@([^:]+):.*|\1|')
  else
    # HTTPS format: https://platform/owner/repo
    PLATFORM=$(echo "$url" | sed -E 's|https?://([^/]+)/.*|\1|')
  fi

  # Extract org and repo
  ORG=$(echo "$url" | sed -E 's|.*[:/]([^/]+)/([^/]+)(\.git)?$|\1|')
  REPO=$(echo "$url" | sed -E 's|.*[:/]([^/]+)/([^/]+)(\.git)?$|\2|' | sed 's/\.git$//')
}

# Parse the URL
parse_repo_url "$REPO_URL"

# Validate we got all parts
if [ -z "$PLATFORM" ] || [ -z "$ORG" ] || [ -z "$REPO" ]; then
  echo "Error: Failed to parse repository URL: $REPO_URL" >&2
  exit 1
fi

# Construct full URL if short form was used
if [[ ! "$REPO_URL" =~ (https?://|git@) ]]; then
  REPO_URL="https://$PLATFORM/$ORG/$REPO.git"
fi

# Set up clone directory
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CLONE_BASE="$XDG_DATA_HOME/claude/repositories"
REPO_PATH="$CLONE_BASE/$PLATFORM/$ORG/$REPO"

# Create directory structure
mkdir -p "$CLONE_BASE/$PLATFORM/$ORG"
cd "$CLONE_BASE/$PLATFORM/$ORG"

# Clone or update repository
if [ -d "$REPO/.git" ]; then
  echo "Repository already exists at $REPO_PATH" >&2
  echo "Updating..." >&2
  cd "$REPO"

  # Fetch latest changes
  git fetch origin --depth 1 2>&1 || echo "Fetch failed, using existing state" >&2

  # Try to pull if on a branch
  if git symbolic-ref --short HEAD &>/dev/null; then
    current_branch=$(git symbolic-ref --short HEAD)
    git pull origin "$current_branch" 2>&1 || echo "Pull failed, using existing state" >&2
  fi
else
  echo "Cloning repository to $REPO_PATH..." >&2
  git clone --depth 1 "$REPO_URL" "$REPO" 2>&1
  cd "$REPO"
fi

# Checkout specific branch if requested
if [ -n "$BRANCH" ]; then
  echo "Checking out branch: $BRANCH" >&2
  git fetch origin "$BRANCH" --depth 1 2>&1 || true
  git checkout "$BRANCH" 2>&1 || echo "Branch checkout failed, using current state" >&2
fi

# Output the final repository path (to stdout for capture)
echo "$REPO_PATH"
