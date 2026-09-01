#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat <<'EOF'
Usage: gather-requirements.sh [--pr-number NUMBER]
Collect explicit requirements linked from a pull request.

Sources, in priority order:
  1. GitHub issues linked with a closing or reference keyword
  2. A Jira key in the PR branch or title
  3. Explicit acceptance criteria in the PR description

The command prints JSON with source, issue_ref, and requirements fields.
A confirmed absence returns source "none". Source access failures are errors.
EOF
}

fatal() {
  local message="$1"
  local status="${2:-1}"

  printf '%s: ERROR: %s\n' "${PROG}" "${message}" >&2
  exit "${status}"
}

main() {
  local pr_number=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --pr-number)
      [[ $# -ge 2 ]] || fatal "--pr-number requires an argument" 2
      pr_number="$2"
      shift 2
      ;;
    --pr-number=*)
      pr_number="${1#*=}"
      shift
      ;;
    *) fatal "unknown argument: $1" 2 ;;
    esac
  done

  if [[ -z "${pr_number}" ]]; then
    local branch
    local candidates
    local candidate_count
    branch="$(git branch --show-current)"
    [[ -n "${branch}" ]] || fatal "cannot infer a pull request from a detached HEAD; use --pr-number"
    candidates="$(gh pr list --head "${branch}" --state open --json number --limit 2)"
    candidate_count="$(jq 'length' <<<"${candidates}")"
    if [[ "${candidate_count}" -eq 0 ]]; then
      jq -n '{source:"none", issue_ref:null, requirements:""}'
      exit 0
    fi
    [[ "${candidate_count}" -eq 1 ]] ||
      fatal "multiple open pull requests match branch '${branch}'; use --pr-number"
    pr_number="$(jq -r '.[0].number' <<<"${candidates}")"
  fi

  [[ "${pr_number}" =~ ^[0-9]+$ ]] || fatal "--pr-number must be numeric" 2

  local pr_json
  local pr_body
  local pr_title
  local branch
  pr_json="$(gh pr view "${pr_number}" --json title,body,headRefName)"
  pr_body="$(jq -r '.body // ""' <<<"${pr_json}")"
  pr_title="$(jq -r '.title // ""' <<<"${pr_json}")"
  branch="$(jq -r '.headRefName // ""' <<<"${pr_json}")"

  local issue_numbers
  local issue_matches
  local command_status
  if issue_matches="$(
    rg -io --pcre2 --replace '$1' \
      '(?:fix(?:es|ed)?|close[sd]?|resolve[sd]?|refs?)\s+#([0-9]+)' \
      <<<"${pr_body}"
  )"; then
    if issue_numbers="$(sort -u <<<"${issue_matches}")"; then
      :
    else
      command_status=$?
      return "${command_status}"
    fi
  else
    command_status=$?
    [[ "${command_status}" -eq 1 ]] || return "${command_status}"
    issue_numbers=""
  fi

  if [[ -n "${issue_numbers}" ]]; then
    local requirements=""
    local issue_refs=""
    local issue_number
    while IFS= read -r issue_number; do
      local issue_json
      local issue_title
      local issue_body
      local section
      issue_json="$(gh issue view "${issue_number}" --json title,body,labels,milestone)"
      issue_title="$(jq -r '.title // ""' <<<"${issue_json}")"
      issue_body="$(jq -r '.body // ""' <<<"${issue_json}")"
      printf -v section '## Issue #%s: %s\n\n%s\n\n' \
        "${issue_number}" "${issue_title}" "${issue_body}"
      requirements+="${section}"
      issue_refs+="#${issue_number} "
    done <<<"${issue_numbers}"

    jq -n \
      --arg source "github-issue" \
      --arg issue_ref "${issue_refs% }" \
      --arg requirements "${requirements%$'\n\n'}" \
      '{source:$source, issue_ref:$issue_ref, requirements:$requirements}'
    exit 0
  fi

  local jira_key
  local jira_matches
  if jira_matches="$(rg -o '[A-Z]+-[0-9]+' <<<"${branch} ${pr_title}")"; then
    if jira_key="$(sed -n '1p' <<<"${jira_matches}")"; then
      :
    else
      command_status=$?
      return "${command_status}"
    fi
  else
    command_status=$?
    [[ "${command_status}" -eq 1 ]] || return "${command_status}"
    jira_key=""
  fi

  if [[ -n "${jira_key}" ]]; then
    command -v jira >/dev/null 2>&1 ||
      fatal "PR references ${jira_key}, but the jira command is unavailable"
    local jira_output
    jira_output="$(jira issue view "${jira_key}")"
    jq -n \
      --arg source "jira" \
      --arg issue_ref "${jira_key}" \
      --arg requirements "${jira_output}" \
      '{source:$source, issue_ref:$issue_ref, requirements:$requirements}'
    exit 0
  fi

  local criteria_count
  if criteria_count="$(
    rg -ci --pcre2 \
      '(acceptance.criter|given\s.+when\s.+then|\- \[[ x]\]|^[0-9]+\.\s)' \
      <<<"${pr_body}"
  )"; then
    :
  else
    command_status=$?
    [[ "${command_status}" -eq 1 ]] || return "${command_status}"
    criteria_count=0
  fi

  if [[ "${criteria_count}" -gt 0 ]]; then
    jq -n \
      --arg source "pr-description" \
      --arg issue_ref "PR #${pr_number}" \
      --arg requirements "## PR #${pr_number}: ${pr_title}\n\n${pr_body}" \
      '{source:$source, issue_ref:$issue_ref, requirements:$requirements}'
    exit 0
  fi

  jq -n '{source:"none", issue_ref:null, requirements:""}'
}

main "$@"
