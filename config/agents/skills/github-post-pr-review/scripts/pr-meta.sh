#!/usr/bin/env bash
# Prints PR metadata as JSON.
# Usage: pr_meta=$(pr-meta.sh)
#
# Output fields: pr_number, commit_id, repo, review_id, comments_file
# review_id is null when no pending review exists for the authenticated user.
# Exits with code 1 and prints an error if no PR exists for the current branch.

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat << 'EOF'
pr-meta.sh — Print PR metadata as JSON.

Usage: pr_meta=$(pr-meta.sh)

Output fields:
  pr_number   Pull request number
  commit_id   HEAD commit SHA of the PR branch
  repo        Repository in owner/repo format
  review_id   ID of an existing pending review for the authenticated user, or null if none
  comments_file  Path to JSON file with review comments ({path, line, body})
Exits with code 1 if no pull request exists for the current branch.
EOF
  exit 0
fi

if ! PR=$(gh pr view --json number,headRefOid 2> /dev/null); then
  echo "error: no pull request found for the current branch" >&2
  exit 1
fi

PR_NUM=$(echo "${PR}" | jq -r '.number')
COMMIT_ID=$(echo "${PR}" | jq -r '.headRefOid')
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
CURRENT_USER=$(gh api user --jq '.login')
if ! REVIEWS=$(gh api --paginate "repos/${REPO}/pulls/${PR_NUM}/reviews" | jq -s 'add'); then
  echo "error: failed to fetch pull request reviews" >&2
  exit 1
fi

if ! REVIEW_ID=$(echo "${REVIEWS}" | jq --arg current_user "${CURRENT_USER}" 'map(select(.state=="PENDING" and .user.login==$current_user)) | first | .id // null'); then
  echo "error: failed to parse pull request reviews" >&2
  exit 1
fi

if ! COMMENTS=$(gh api --paginate "repos/${REPO}/pulls/${PR_NUM}/comments" | jq -s 'add | map({path, line, body})'); then
  echo "error: failed to fetch pull request comments" >&2
  exit 1
fi
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
COMMENTS_FILE=$(mktemp "/tmp/github-post-pr-review-${TIMESTAMP}-comments-XXXXXX.json")
printf '%s\n' "${COMMENTS}" > "${COMMENTS_FILE}"

jq -n \
  --argjson pr_number "${PR_NUM}" \
  --arg commit_id "${COMMIT_ID}" \
  --arg repo "${REPO}" \
  --argjson review_id "${REVIEW_ID}" \
  --arg comments_file "${COMMENTS_FILE}" \
  '{ pr_number: $pr_number, commit_id: $commit_id, repo: $repo, review_id: $review_id, comments_file: $comments_file }'
