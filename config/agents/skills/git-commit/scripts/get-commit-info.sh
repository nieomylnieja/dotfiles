#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"
temporary_dir=""

usage() {
  cat <<'EOF'
Usage: get-commit-info.sh
Print bounded working-tree and commit-style metadata as JSON.

The command does not modify the index or working tree.
EOF
}

fatal() {
  printf '%s: ERROR: %s\n' "${PROG}" "$1" >&2
  exit "${2:-1}"
}

cleanup() {
  if [[ -n "${temporary_dir}" && -d "${temporary_dir}" ]]; then
    rm -rf -- "${temporary_dir}"
  fi
}

name_status_json() {
  jq -Rs '
    def records:
      if length == 0 then []
      else .[0] as $status
        | if ($status | test("^[RC][0-9]*$")) then
            [{status: $status, old_path: .[1], path: .[2]}]
            + (.[3:] | records)
          else
            [{status: $status, path: .[1]}]
            + (.[2:] | records)
          end
      end;
    split("\u0000")
    | if last == "" then .[:-1] else . end
    | records
  ' "$1"
}

if [[ $# -gt 0 ]]; then
  if [[ $# -eq 1 && "$1" == "--help" ]]; then
    usage
    exit 0
  fi
  fatal "unknown argument: $1" 2
fi

git rev-parse --git-dir >/dev/null
current_branch="$(git branch --show-current)"
[[ -n "${current_branch}" ]] || fatal "detached HEAD has no commit branch"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
temporary_dir="$(mktemp -d "/tmp/get-commit-info-${timestamp}-XXXXXX")"
trap cleanup EXIT

git diff --cached --name-status -z >"${temporary_dir}/staged"
git diff --name-status -z >"${temporary_dir}/unstaged"
git ls-files --others --exclude-standard -z >"${temporary_dir}/untracked"
git diff --cached --stat >"${temporary_dir}/staged-stat"
if git rev-parse --verify --quiet HEAD >/dev/null; then
  git log -5 -z --format='%h%x00%s' >"${temporary_dir}/recent"
else
  : >"${temporary_dir}/recent"
fi

staged_files_json="$(name_status_json "${temporary_dir}/staged")"
unstaged_files_json="$(name_status_json "${temporary_dir}/unstaged")"
untracked_files_json="$(
  jq -Rs '
    split("\u0000")
    | if last == "" then .[:-1] else . end
    | map({status: "?", path: .})
  ' "${temporary_dir}/untracked"
)"
unstaged_files_json="$(
  jq -n \
    --argjson tracked "${unstaged_files_json}" \
    --argjson untracked "${untracked_files_json}" \
    '$tracked + $untracked'
)"
recent_commits_json="$(
  jq -Rs '
    split("\u0000")
    | if last == "" then .[:-1] else . end
    | [range(0; length; 2) as $index
       | {hash: .[$index], message: .[$index + 1]}]
  ' "${temporary_dir}/recent"
)"

has_staged="$(jq 'length > 0' <<<"${staged_files_json}")"
has_unstaged="$(jq 'length > 0' <<<"${unstaged_files_json}")"
if [[ "${has_staged}" == "false" && "${has_unstaged}" == "false" ]]; then
  nothing_to_commit="true"
else
  nothing_to_commit="false"
fi

issue_number=""
if [[ "${current_branch}" =~ ([A-Z]+-[0-9]+) ]]; then
  issue_number="${BASH_REMATCH[1]}"
elif [[ "${current_branch}" =~ (^|[^0-9])([0-9]+)([^0-9]|$) ]]; then
  issue_number="${BASH_REMATCH[2]}"
fi

jq -n \
  --arg current_branch "${current_branch}" \
  --argjson has_staged "${has_staged}" \
  --argjson has_unstaged "${has_unstaged}" \
  --argjson nothing_to_commit "${nothing_to_commit}" \
  --argjson staged_files "${staged_files_json}" \
  --argjson unstaged_files "${unstaged_files_json}" \
  --rawfile staged_stat "${temporary_dir}/staged-stat" \
  --argjson recent_commits "${recent_commits_json}" \
  --arg issue_number "${issue_number}" \
  '{
    current_branch: $current_branch,
    has_staged: $has_staged,
    has_unstaged: $has_unstaged,
    nothing_to_commit: $nothing_to_commit,
    staged_files: $staged_files,
    unstaged_files: $unstaged_files,
    staged_stat: ($staged_stat | rtrimstr("\n")),
    recent_commits: $recent_commits,
    issue_number: ($issue_number | if . == "" then null else . end)
  }'
