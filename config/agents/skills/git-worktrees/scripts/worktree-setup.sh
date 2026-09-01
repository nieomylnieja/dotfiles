#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat <<EOF
Usage: ${PROG} [OPTION]... BRANCH
Create or reuse .worktrees/BRANCH without changing existing work.

Options:
  -b, --base BRANCH       base for a new branch (default: cached remote default)
      --commit COMMIT     create or verify a detached checkout at COMMIT
      --fetch             fetch the selected branch or base before creation
  -h, --help              display this help and exit

The command prints JSON metadata for the resolved worktree.

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

detect_cached_default_branch() {
  local remote_head

  remote_head="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || true)"
  [[ "${remote_head}" == refs/remotes/origin/* ]] ||
    fatal "cannot detect the cached remote default branch; use --base"
  printf '%s\n' "${remote_head#refs/remotes/origin/}"
}

main() {
  local base=""
  local branch=""
  local commit=""
  local fetch=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -b | --base)
      [[ $# -ge 2 ]] || fatal "--base requires an argument" 2
      base="$2"
      shift 2
      ;;
    --base=*)
      base="${1#*=}"
      shift
      ;;
    --fetch)
      fetch=true
      shift
      ;;
    --commit)
      [[ $# -ge 2 ]] || fatal "--commit requires an argument" 2
      commit="$2"
      shift 2
      ;;
    --commit=*)
      commit="${1#*=}"
      shift
      ;;
    --)
      shift
      break
      ;;
    -*) fatal "unknown option: $1" 2 ;;
    *) break ;;
    esac
  done

  [[ $# -eq 1 ]] || fatal "expected one BRANCH argument" 2
  branch="$1"
  git check-ref-format --branch "${branch}" >/dev/null || fatal "invalid branch name: ${branch}" 2
  if [[ -n "${commit}" && "${fetch}" == true ]]; then
    fatal "--commit and --fetch cannot be combined; fetch the exact object before setup" 2
  fi

  local repo_root
  local worktree_path
  local created=false
  local branch_ref="refs/heads/${branch}"
  local resolved_commit=""
  repo_root="$(git rev-parse --show-toplevel)"
  worktree_path="${repo_root}/.worktrees/${branch}"
  if [[ -n "${commit}" ]]; then
    resolved_commit="$(git rev-parse --verify --end-of-options "${commit}^{commit}")" ||
      fatal "commit is not available locally: ${commit}"
  fi

  local branch_is_checked_out=false
  if [[ ! -e "${worktree_path}/.git" && -z "${resolved_commit}" ]]; then
    local worktree_list
    local command_status
    if worktree_list="$(git worktree list --porcelain)"; then
      :
    else
      command_status=$?
      return "${command_status}"
    fi
    if rg -Fxq "branch ${branch_ref}" <<<"${worktree_list}"; then
      branch_is_checked_out=true
    else
      command_status=$?
      [[ "${command_status}" -eq 1 ]] || return "${command_status}"
    fi
  fi

  if [[ -e "${worktree_path}/.git" ]]; then
    if [[ -n "${resolved_commit}" ]]; then
      local existing_head
      local existing_branch
      existing_head="$(git -C "${worktree_path}" rev-parse HEAD)"
      [[ "${existing_head}" == "${resolved_commit}" ]] ||
        fatal "${worktree_path} is at ${existing_head}, expected ${resolved_commit}"
      existing_branch="$(git -C "${worktree_path}" branch --show-current)"
      [[ -z "${existing_branch}" ]] ||
        fatal "${worktree_path} is attached to branch '${existing_branch}', expected a detached checkout"
    else
      local existing_branch
      existing_branch="$(git -C "${worktree_path}" branch --show-current)"
      [[ "${existing_branch}" == "${branch}" ]] ||
        fatal "${worktree_path} contains branch '${existing_branch}', expected '${branch}'"
    fi
  elif [[ "${branch_is_checked_out}" == true ]]; then
    fatal "branch '${branch}' is already checked out in another worktree"
  else
    mkdir -p -- "${worktree_path%/*}"

    if "${fetch}"; then
      if git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
        git fetch origin "refs/heads/${branch}:refs/remotes/origin/${branch}"
      else
        local remote_probe
        local remote_status
        if remote_probe="$(git ls-remote --exit-code --heads origin "${branch}" 2>&1)"; then
          git fetch origin "refs/heads/${branch}:refs/remotes/origin/${branch}"
        else
          remote_status=$?
          [[ "${remote_status}" -eq 2 ]] ||
            fatal "cannot probe remote branch '${branch}': ${remote_probe}"
          if [[ -z "${base}" ]]; then
            base="$(detect_cached_default_branch)"
          fi
          git fetch origin "refs/heads/${base}:refs/remotes/origin/${base}"
        fi
      fi
    fi

    if [[ -n "${resolved_commit}" ]]; then
      git worktree add --quiet --detach "${worktree_path}" "${resolved_commit}"
    elif git show-ref --verify --quiet "${branch_ref}"; then
      git worktree add --quiet "${worktree_path}" "${branch}"
    elif git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
      git worktree add --quiet --track -b "${branch}" "${worktree_path}" "origin/${branch}"
    else
      [[ -n "${base}" ]] || base="$(detect_cached_default_branch)"
      local base_ref="${base}"
      if git show-ref --verify --quiet "refs/remotes/origin/${base}"; then
        base_ref="origin/${base}"
      elif ! git show-ref --verify --quiet "refs/heads/${base}"; then
        fatal "base branch '${base}' is not available locally; rerun with --fetch"
      fi
      git worktree add --quiet -b "${branch}" "${worktree_path}" "${base_ref}"
    fi
    created=true
  fi

  local head
  local checked_out_branch
  local status
  head="$(git -C "${worktree_path}" rev-parse HEAD)"
  checked_out_branch="$(git -C "${worktree_path}" branch --show-current)"
  status="$(git -C "${worktree_path}" status --short)"

  jq -n \
    --arg repo_root "${repo_root}" \
    --arg worktree_path "${worktree_path}" \
    --arg label "${branch}" \
    --arg branch "${checked_out_branch}" \
    --arg head "${head}" \
    --arg status "${status}" \
    --argjson created "${created}" \
    '{repo_root: $repo_root, worktree_path: $worktree_path, label: $label, branch: ($branch | if . == "" then null else . end), head: $head, created: $created, dirty: ($status != ""), status: $status}'
}

main "$@"
