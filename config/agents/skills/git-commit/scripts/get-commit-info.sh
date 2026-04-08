#!/usr/bin/env bash
# Gathers all information needed to create a git commit

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat << 'EOF'
get-commit-info.sh — Gather all information needed to create a git commit.

Usage: get-commit-info.sh

Outputs a JSON object to stdout with:
  current_branch        Current git branch name
  has_staged            Whether there are staged changes
  has_unstaged          Whether there are unstaged changes
  nothing_to_commit     Whether working tree is clean
  staged_files          Array of {status, path} objects for staged files
  unstaged_files        Array of {status, path} objects for unstaged files
  staged_stat           Summary line from git diff --cached --stat
  staged_diff           Full diff of staged changes
  recent_commits        Array of {hash, message} for last 5 commits (style reference)
  issue_number          Issue/ticket number extracted from branch name, or null
EOF
  exit 0
fi

echo "Gathering commit information..." >&2

# Get current branch
current_branch=$(git branch --show-current)
if [[ -z "${current_branch}" ]]; then
  echo "Error: Not on a branch (detached HEAD?)" >&2
  exit 1
fi
echo "Current branch: ${current_branch}" >&2

# Parse staged files
staged_files_json="[]"
has_staged=false
staged_raw=$(git diff --cached --name-status 2> /dev/null || true)
if [[ -n "${staged_raw}" ]]; then
  has_staged=true
  staged_files_json=$(echo "${staged_raw}" | awk '{print "{\"status\":\""$1"\",\"path\":\""$2"\"}"}' | jq -s '.')
fi

# Parse unstaged files
unstaged_files_json="[]"
has_unstaged=false
unstaged_raw=$(git diff --name-status 2> /dev/null || true)
if [[ -n "${unstaged_raw}" ]]; then
  has_unstaged=true
  unstaged_files_json=$(echo "${unstaged_raw}" | awk '{print "{\"status\":\""$1"\",\"path\":\""$2"\"}"}' | jq -s '.')
fi

# Check for untracked files too (include in unstaged count)
untracked_raw=$(git ls-files --others --exclude-standard 2> /dev/null || true)
if [[ -n "${untracked_raw}" ]]; then
  has_unstaged=true
  untracked_json=$(echo "${untracked_raw}" | jq -R '{"status":"?","path":.}' | jq -s '.')
  unstaged_files_json=$(jq -s '.[0] + .[1]' <(echo "${unstaged_files_json}") <(echo "${untracked_json}"))
fi

# Nothing to commit?
nothing_to_commit=false
if ! ${has_staged} && ! ${has_unstaged}; then
  nothing_to_commit=true
fi

# Staged stat summary
staged_stat=""
if ${has_staged}; then
  staged_stat=$(git diff --cached --stat 2> /dev/null | tail -1 || true)
fi

# Full staged diff (for message generation) — written to temp file to avoid ARG_MAX
staged_diff_file=$(mktemp "/tmp/staged-diff-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")
trap 'rm -f "${staged_diff_file}"' EXIT
if ${has_staged}; then
  git diff --cached 2> /dev/null > "${staged_diff_file}" || true
fi

# Recent commits for style reference
echo "Fetching recent commits..." >&2
recent_commits_json=$(git log --oneline -5 --format='{"hash":"%h","message":"%s"}' 2> /dev/null | jq -s '.' || echo '[]')

# Extract issue number from branch name
# Supports: feature-123-desc, fix/456-desc, PROJ-789-desc, ABC-42
issue_number=""
if [[ "${current_branch}" =~ ([A-Z]+-[0-9]+) ]]; then
  issue_number="${BASH_REMATCH[1]}"
elif [[ "${current_branch}" =~ [^0-9]([0-9]+)[^0-9] ]] || [[ "${current_branch}" =~ ^([0-9]+)[-_] ]]; then
  issue_number="${BASH_REMATCH[1]}"
fi

echo "" >&2
echo "Done!" >&2

jq -n \
  --arg current_branch "${current_branch}" \
  --argjson has_staged "${has_staged}" \
  --argjson has_unstaged "${has_unstaged}" \
  --argjson nothing_to_commit "${nothing_to_commit}" \
  --argjson staged_files "${staged_files_json}" \
  --argjson unstaged_files "${unstaged_files_json}" \
  --arg staged_stat "${staged_stat}" \
  --rawfile staged_diff "${staged_diff_file}" \
  --argjson recent_commits "${recent_commits_json}" \
  --arg issue_number "${issue_number}" \
  '{
    current_branch: $current_branch,
    has_staged: $has_staged,
    has_unstaged: $has_unstaged,
    nothing_to_commit: $nothing_to_commit,
    staged_files: $staged_files,
    unstaged_files: $unstaged_files,
    staged_stat: $staged_stat,
    staged_diff: $staged_diff,
    recent_commits: $recent_commits,
    issue_number: ($issue_number | if . == "" then null else . end)
  }'
