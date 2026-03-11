#!/usr/bin/env bash
# Gathers all information needed to create a GitHub Pull Request

set -euo pipefail

echo "Gathering PR information..." >&2

# Get current branch
current_branch=$(git branch --show-current)
if [ -z "$current_branch" ]; then
  echo "Error: Not on a branch (detached HEAD?)" >&2
  exit 1
fi

echo "Current branch: $current_branch" >&2

# Get base branch (main or master)
base_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||' || echo "main")
echo "Base branch: $base_branch" >&2

# Check if on main/master
on_main_or_master=false
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
  on_main_or_master=true
fi

# Check if branch has upstream tracking
has_upstream=false
upstream_status="unknown"
if git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
  has_upstream=true

  # Determine upstream status (ahead/behind/up-to-date/diverged)
  upstream_branch=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})
  local_commit=$(git rev-parse @)
  remote_commit=$(git rev-parse @{u})
  base_commit=$(git merge-base @ @{u})

  if [ "$local_commit" = "$remote_commit" ]; then
    upstream_status="up-to-date"
  elif [ "$local_commit" = "$base_commit" ]; then
    upstream_status="behind"
  elif [ "$remote_commit" = "$base_commit" ]; then
    upstream_status="ahead"
  else
    upstream_status="diverged"
  fi
fi

# Get commits between base and current branch
echo "Analyzing commits..." >&2
commits_json="[]"
commits_count=0
if ! $on_main_or_master; then
  # Get commits as JSON array
  commits_json=$(git log origin/$base_branch..HEAD --format='{"hash":"%h","message":"%s"}' 2>/dev/null | jq -s '.' || echo '[]')
  commits_count=$(echo "$commits_json" | jq 'length')
fi

# Get diff stats (files changed, insertions, deletions)
echo "Analyzing changes..." >&2
files_changed=0
insertions=0
deletions=0
if ! $on_main_or_master && [ "$commits_count" -gt 0 ]; then
  # Get the stat summary line
  stat_line=$(git diff origin/$base_branch...HEAD --shortstat 2>/dev/null || echo "")

  if [ -n "$stat_line" ]; then
    # Parse: "3 files changed, 120 insertions(+), 45 deletions(-)"
    files_changed=$(echo "$stat_line" | grep -oP '\d+(?= file)' || echo "0")
    insertions=$(echo "$stat_line" | grep -oP '\d+(?= insertion)' || echo "0")
    deletions=$(echo "$stat_line" | grep -oP '\d+(?= deletion)' || echo "0")
  fi
fi

# Check for uncommitted changes
uncommitted_changes=false
uncommitted_files="[]"
status_output=$(git status --short --porcelain)
if [ -n "$status_output" ]; then
  uncommitted_changes=true
  # Convert git status output to JSON array
  uncommitted_files=$(echo "$status_output" | jq -R . | jq -s '.')
fi

# Read PR template if it exists
pr_template=""
pr_template_path=""
for template_path in .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md docs/pull_request_template.md; do
  if [ -f "$template_path" ]; then
    pr_template=$(cat "$template_path")
    pr_template_path="$template_path"
    echo "Found PR template: $pr_template_path" >&2
    break
  fi
done

# Check for existing PR on this branch
echo "Checking for existing PR..." >&2
existing_pr_number=""
existing_pr_url=""
if ! $on_main_or_master; then
  existing_pr_data=$(gh pr list --head "$current_branch" --json number,url --jq '.[0]' 2>/dev/null || echo "{}")
  existing_pr_number=$(echo "$existing_pr_data" | jq -r '.number // empty')
  existing_pr_url=$(echo "$existing_pr_data" | jq -r '.url // empty')

  if [ -n "$existing_pr_number" ]; then
    echo "Found existing PR #$existing_pr_number" >&2
  fi
fi

# Build final JSON output
echo "" >&2
echo "Done!" >&2

jq -n \
  --arg current_branch "$current_branch" \
  --arg base_branch "$base_branch" \
  --argjson on_main_or_master "$on_main_or_master" \
  --argjson has_upstream "$has_upstream" \
  --arg upstream_status "$upstream_status" \
  --argjson commits "$commits_json" \
  --argjson commits_count "$commits_count" \
  --argjson files_changed "$files_changed" \
  --argjson insertions "$insertions" \
  --argjson deletions "$deletions" \
  --argjson uncommitted_changes "$uncommitted_changes" \
  --argjson uncommitted_files "$uncommitted_files" \
  --arg pr_template "$pr_template" \
  --arg pr_template_path "$pr_template_path" \
  --arg existing_pr_number "$existing_pr_number" \
  --arg existing_pr_url "$existing_pr_url" \
  '{
    current_branch: $current_branch,
    base_branch: $base_branch,
    on_main_or_master: $on_main_or_master,
    has_upstream: $has_upstream,
    upstream_status: $upstream_status,
    commits: $commits,
    commits_count: $commits_count,
    files_changed: $files_changed,
    insertions: $insertions,
    deletions: $deletions,
    uncommitted_changes: $uncommitted_changes,
    uncommitted_files: $uncommitted_files,
    pr_template: $pr_template,
    pr_template_path: $pr_template_path,
    existing_pr_number: ($existing_pr_number | if . == "" then null else . end),
    existing_pr_url: ($existing_pr_url | if . == "" then null else . end)
  }'
