#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat << EOF
Usage: ${PROG} [OPTION]... BRANCH
Create or update a git worktree at .worktrees/BRANCH.

Auto-detects whether BRANCH exists (locally or on origin).
  - Existing branch: fetches latest and checks it out.
  - New branch: fetches the base branch, then creates BRANCH from it.

Options:
  -b, --base BRANCH  base branch to create from (default: auto-detect main/master)
  -h, --help         display this help and exit

Exit status:
  0  success
  1  general error
  2  usage error
EOF
}

log() { echo "${PROG}: $*" >&2; }
fatal() {
  echo "${PROG}: ERROR: $1" >&2
  exit "${2:-1}"
}

detect_default_branch() {
  local remote_head
  remote_head="$(git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null || true)"
  if [[ -n "${remote_head}" ]]; then
    echo "${remote_head#refs/remotes/origin/}"
    return
  fi
  for candidate in main master; do
    if git rev-parse --verify "origin/${candidate}" &> /dev/null; then
      echo "${candidate}"
      return
    fi
  done
  fatal "cannot detect default branch; use --base to specify"
}

branch_exists_on_remote() {
  git ls-remote --exit-code --heads origin "$1" &> /dev/null
}

branch_exists_locally() {
  git rev-parse --verify "refs/heads/$1" &> /dev/null
}

main() {
  local base=""
  local branch=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -b | --base)
        [[ $# -lt 2 ]] && fatal "--base requires an argument" 2
        base="$2"
        shift 2
        ;;
      --base=*)
        base="${1#*=}"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*) fatal "Unknown option: $1" 2 ;;
      *) break ;;
    esac
  done

  [[ $# -eq 0 ]] && fatal "BRANCH argument is required" 2
  [[ $# -gt 1 ]] && fatal "expected exactly one BRANCH argument, got $#" 2
  branch="$1"

  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"
  local worktree_path="${repo_root}/.worktrees/${branch}"

  if branch_exists_on_remote "${branch}" || branch_exists_locally "${branch}"; then
    local on_remote
    on_remote=$(branch_exists_on_remote "${branch}" && echo true || echo false)

    if [[ "${on_remote}" == "true" ]]; then
      log "Branch '${branch}' exists on remote, fetching latest..."
      git fetch origin "${branch}"
    else
      log "Branch '${branch}' exists locally (not on remote)..."
    fi

    if [[ ! -d "${worktree_path}" ]]; then
      log "Creating worktree at ${worktree_path}..."
      if branch_exists_locally "${branch}"; then
        git worktree add "${worktree_path}" "${branch}"
      else
        git worktree add --track -b "${branch}" "${worktree_path}" "origin/${branch}"
      fi
    fi

    if [[ "${on_remote}" == "true" ]]; then
      log "Resetting to origin/${branch}..."
      git -C "${worktree_path}" reset --hard "origin/${branch}"
    fi
  else
    if [[ -z "${base}" ]]; then
      base="$(detect_default_branch)"
    fi

    log "Branch '${branch}' is new, branching off '${base}'..."
    log "Fetching '${base}' from origin..."
    git fetch origin "${base}"

    log "Creating worktree at ${worktree_path}..."
    git worktree add -b "${branch}" "${worktree_path}" "origin/${base}"
  fi

  echo "${worktree_path}"
}

main "$@"
