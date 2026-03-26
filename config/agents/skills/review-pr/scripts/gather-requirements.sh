#!/usr/bin/env bash
# Gathers requirements from GitHub issue, Jira ticket, or PR description.
# Prints JSON: { "source": "<source>", "requirements": "<text>" }
# Exit code 0 with empty requirements means no requirements found.
#
# Usage: gather-requirements.sh [--pr-number N]

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'EOF'
gather-requirements.sh — Collect requirements for a PR.

Checks these sources in order, stops at the first hit:
  1. GitHub issues linked via closing keywords in the PR body
  2. Jira ticket ID in branch name or PR title
  3. PR description itself (if it contains acceptance criteria)

Output (JSON):
  source         "github-issue" | "jira" | "pr-description" | "none"
  issue_ref      Issue/ticket identifier (e.g. "#42", "FEAT-123") or null
  requirements   The requirements text, or empty string

Usage:
  gather-requirements.sh              # auto-detect PR from current branch
  gather-requirements.sh --pr-number 42
EOF
  exit 0
fi

PR_NUMBER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr-number) PR_NUMBER="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Detect PR number if not provided
if [[ -z "$PR_NUMBER" ]]; then
  PR_NUMBER=$(gh pr view --json number -q '.number' 2>/dev/null || echo "")
fi

if [[ -z "$PR_NUMBER" ]]; then
  jq -n '{source:"none", issue_ref:null, requirements:""}'
  exit 0
fi

PR_JSON=$(gh pr view "$PR_NUMBER" --json title,body,headRefName)
PR_BODY=$(echo "$PR_JSON" | jq -r '.body // ""')
PR_TITLE=$(echo "$PR_JSON" | jq -r '.title // ""')
BRANCH=$(echo "$PR_JSON" | jq -r '.headRefName // ""')

# 1. GitHub issue — closing keywords in PR body
ISSUE_NUMS=$(echo "$PR_BODY" | grep -ioP '(?:fix(?:es|ed)?|close[sd]?|resolve[sd]?|refs?)\s+#\K[0-9]+' | sort -u || true)

if [[ -n "$ISSUE_NUMS" ]]; then
  REQUIREMENTS=""
  ISSUE_REFS=""
  for NUM in $ISSUE_NUMS; do
    ISSUE_JSON=$(gh issue view "$NUM" --json title,body,labels,milestone 2>/dev/null || echo "")
    if [[ -n "$ISSUE_JSON" ]]; then
      ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title // ""')
      ISSUE_BODY=$(echo "$ISSUE_JSON" | jq -r '.body // ""')
      REQUIREMENTS="${REQUIREMENTS}## Issue #${NUM}: ${ISSUE_TITLE}\n\n${ISSUE_BODY}\n\n"
      ISSUE_REFS="${ISSUE_REFS}#${NUM} "
    fi
  done
  if [[ -n "$REQUIREMENTS" ]]; then
    jq -n \
      --arg source "github-issue" \
      --arg issue_ref "${ISSUE_REFS% }" \
      --arg requirements "$(echo -e "$REQUIREMENTS")" \
      '{source:$source, issue_ref:$issue_ref, requirements:$requirements}'
    exit 0
  fi
fi

# 2. Jira ticket — pattern in branch name or PR title
JIRA_KEY=$(echo "$BRANCH $PR_TITLE" | grep -oP '[A-Z]+-[0-9]+' | head -1 || true)

if [[ -n "$JIRA_KEY" ]]; then
  JIRA_OUTPUT=$(jira issue view "$JIRA_KEY" 2>/dev/null || echo "")
  if [[ -n "$JIRA_OUTPUT" ]]; then
    jq -n \
      --arg source "jira" \
      --arg issue_ref "$JIRA_KEY" \
      --arg requirements "$JIRA_OUTPUT" \
      '{source:$source, issue_ref:$issue_ref, requirements:$requirements}'
    exit 0
  fi
fi

# 3. PR description — check if it has acceptance criteria
# Look for checkboxes, "acceptance criteria", numbered lists, given/when/then
HAS_CRITERIA=$(echo "$PR_BODY" | grep -ciP '(acceptance.criter|given\s.+when\s.+then|\- \[[ x]\]|^\d+\.\s)' || echo "0")

if [[ "$HAS_CRITERIA" -gt 0 ]]; then
  jq -n \
    --arg source "pr-description" \
    --arg issue_ref "PR #${PR_NUMBER}" \
    --arg requirements "## PR #${PR_NUMBER}: ${PR_TITLE}\n\n${PR_BODY}" \
    '{source:$source, issue_ref:$issue_ref, requirements:$requirements}'
  exit 0
fi

# 4. If PR body is non-trivial (>100 chars), use it as a fallback
if [[ ${#PR_BODY} -gt 100 ]]; then
  jq -n \
    --arg source "pr-description" \
    --arg issue_ref "PR #${PR_NUMBER}" \
    --arg requirements "## PR #${PR_NUMBER}: ${PR_TITLE}\n\n${PR_BODY}" \
    '{source:$source, issue_ref:$issue_ref, requirements:$requirements}'
  exit 0
fi

# Nothing found
jq -n \
  --arg jira_key "${JIRA_KEY:-}" \
  '{source:"none", issue_ref:null, requirements:"", jira_attempted:($jira_key | length > 0)}'
