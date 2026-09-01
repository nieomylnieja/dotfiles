#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat <<EOF
Usage: ${PROG} [--base BRANCH]
Print JSON metadata for creating a pull request.

Options:
  -b, --base BRANCH  target branch (default: current remote HEAD)
  -h, --help         display this help and exit

Exit status:
  0  success
  1  operational error
  2  usage error
EOF
}

fatal() {
  local message="$1"
  local status="${2:-1}"

  printf '%s: ERROR: %s\n' "${PROG}" "${message}" >&2
  exit "${status}"
}

detect_default_branch() {
  local remote_info
  local remote_ref
  local branch

  remote_info="$(git ls-remote --symref origin HEAD)" ||
    fatal "cannot resolve origin's current default branch; use --base"
  remote_ref="$(
    awk '$1 == "ref:" && $3 == "HEAD" {print $2}' <<<"${remote_info}"
  )"
  [[ -n "${remote_ref}" && "${remote_ref}" != *$'\n'* ]] ||
    fatal "origin returned an ambiguous default branch; use --base"
  [[ "${remote_ref}" == refs/heads/* ]] ||
    fatal "origin returned an invalid default branch: ${remote_ref}"
  branch="${remote_ref#refs/heads/}"
  git check-ref-format --branch "${branch}" >/dev/null ||
    fatal "origin returned an invalid default branch: ${remote_ref}"
  printf '%s\n' "${branch}"
}

remote_base_commit() {
  local base_branch="$1"
  local remote_line

  remote_line="$(git ls-remote --exit-code origin "refs/heads/${base_branch}")" ||
    fatal "cannot resolve current remote base 'origin/${base_branch}'"
  printf '%s\n' "${remote_line%%[[:space:]]*}"
}

main() {
  local base_branch=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -b | --base)
      [[ $# -ge 2 ]] || fatal "--base requires an argument" 2
      base_branch="$2"
      shift 2
      ;;
    --base=*)
      base_branch="${1#*=}"
      shift
      ;;
    *) fatal "unknown argument: $1" 2 ;;
    esac
  done

  local current_branch
  current_branch="$(git branch --show-current)"
  [[ -n "${current_branch}" ]] || fatal "not on a branch"
  [[ -n "${base_branch}" ]] || base_branch="$(detect_default_branch)"

  local base_ref="refs/remotes/origin/${base_branch}"
  git show-ref --verify --quiet "${base_ref}" ||
    fatal "base branch 'origin/${base_branch}' is not available locally"

  local head_commit
  local base_commit
  local remote_base
  local merge_base
  head_commit="$(git rev-parse HEAD)"
  base_commit="$(git rev-parse "${base_ref}")"
  remote_base="$(remote_base_commit "${base_branch}")"
  [[ "${base_commit}" == "${remote_base}" ]] ||
    fatal "cached ${base_ref} is ${base_commit}, but the remote base is ${remote_base}; fetch the base before creating the PR"
  merge_base="$(git merge-base "${base_ref}" HEAD)"

  local on_base=false
  [[ "${current_branch}" == "${base_branch}" ]] && on_base=true

  local has_upstream=false
  local upstream=""
  local ahead=0
  local behind=0
  local upstream_status="none"
  if upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"; then
    has_upstream=true
    local rev_list_counts
    local command_status
    if rev_list_counts="$(git rev-list --left-right --count "${upstream}...HEAD")"; then
      :
    else
      command_status=$?
      return "${command_status}"
    fi
    [[ "${rev_list_counts}" =~ ^[0-9]+[[:space:]]+[0-9]+$ ]] ||
      fatal "unexpected rev-list count output: ${rev_list_counts}"
    read -r behind ahead <<<"${rev_list_counts}"
    case "${behind}:${ahead}" in
    0:0) upstream_status="up-to-date" ;;
    0:*) upstream_status="ahead" ;;
    *:0) upstream_status="behind" ;;
    *) upstream_status="diverged" ;;
    esac
  fi

  local commits_json
  commits_json="$(
    git log --format='%h%x09%s' "${merge_base}..HEAD" |
      jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {hash: .[0], message: (.[1:] | join("\t"))})'
  )"

  local diff_stats
  diff_stats="$(
    git diff --numstat "${merge_base}...HEAD" |
      awk '{files += 1; if ($1 ~ /^[0-9]+$/) add += $1; if ($2 ~ /^[0-9]+$/) del += $2} END {printf "%d %d %d", files, add, del}'
  )"
  local files_changed insertions deletions
  read -r files_changed insertions deletions <<<"${diff_stats}"

  local uncommitted_files
  uncommitted_files="$(
    git status --porcelain=v1 -z |
      jq -Rs '
          (split("\u0000") | if .[-1] == "" then .[:-1] else . end) as $records
          | reduce range(0; $records | length) as $index
              ({items: [], skip: false};
                if .skip then
                  .skip = false
                else
                  ($records[$index]) as $record
                  | ($record[0:2]) as $status
                  | ($record[3:]) as $path
                  | if ($status | test("[RC]")) then
                      .items += [{
                        status: $status,
                        path: $path,
                        original_path: ($records[$index + 1] // null)
                      }]
                      | .skip = true
                    else
                      .items += [{status: $status, path: $path}]
                    end
                end)
          | .items
        '
  )"

  local existing_pr_json
  local existing_pr_matches
  local existing_pr_count
  local existing_pr
  existing_pr_json="$(
    gh pr list \
      --head "${current_branch}" \
      --base "${base_branch}" \
      --state open \
      --json number,url,baseRefName,headRefName \
      --limit 100
  )"
  existing_pr_matches="$(
    jq \
      --arg head "${current_branch}" \
      --arg base "${base_branch}" \
      '[.[] | select(.headRefName == $head and .baseRefName == $base)]' \
      <<<"${existing_pr_json}"
  )"
  existing_pr_count="$(jq 'length' <<<"${existing_pr_matches}")"
  [[ "${existing_pr_count}" -le 1 ]] ||
    fatal "multiple open pull requests match head '${current_branch}' and base '${base_branch}'"
  existing_pr="$(jq '.[0] // null' <<<"${existing_pr_matches}")"

  jq -n \
    --arg current_branch "${current_branch}" \
    --arg base_branch "${base_branch}" \
    --arg head_commit "${head_commit}" \
    --arg base_commit "${base_commit}" \
    --arg remote_base_commit "${remote_base}" \
    --arg merge_base "${merge_base}" \
    --arg upstream "${upstream}" \
    --arg upstream_status "${upstream_status}" \
    --argjson on_base "${on_base}" \
    --argjson has_upstream "${has_upstream}" \
    --argjson ahead "${ahead}" \
    --argjson behind "${behind}" \
    --argjson commits "${commits_json}" \
    --argjson files_changed "${files_changed}" \
    --argjson insertions "${insertions}" \
    --argjson deletions "${deletions}" \
    --argjson uncommitted_files "${uncommitted_files}" \
    --argjson existing_pr "${existing_pr}" \
    '{
      current_branch: $current_branch,
      base_branch: $base_branch,
      head_commit: $head_commit,
      base_commit: $base_commit,
      remote_base_commit: $remote_base_commit,
      merge_base: $merge_base,
      on_base: $on_base,
      has_upstream: $has_upstream,
      upstream: ($upstream | if . == "" then null else . end),
      upstream_status: $upstream_status,
      ahead: $ahead,
      behind: $behind,
      commits: $commits,
      commits_count: ($commits | length),
      files_changed: $files_changed,
      insertions: $insertions,
      deletions: $deletions,
      uncommitted_changes: ($uncommitted_files | length > 0),
      uncommitted_files: $uncommitted_files,
      existing_pr_number: ($existing_pr.number // null),
      existing_pr_url: ($existing_pr.url // null),
      existing_pr_base: ($existing_pr.baseRefName // null),
      existing_pr_head: ($existing_pr.headRefName // null)
    }'
}

main "$@"
