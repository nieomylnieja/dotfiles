#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat << EOF
Usage: ${PROG} [OPTION]... [BRANCH]
Create or update a git worktree at .worktrees/BRANCH.

Auto-detects whether BRANCH exists (locally or on origin).
  - Existing branch: fetches latest and checks it out.
  - New branch: fetches the base branch, then creates BRANCH from it.
  - No BRANCH: select from available local/origin branches, or create a new one.

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

require_command() {
  local cmd="$1"

  if ! command -v "${cmd}" > /dev/null 2>&1; then
    fatal "missing required command: ${cmd}"
  fi
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

occupied_worktree_branches() {
  git worktree list --porcelain | awk '
    /^branch refs\/heads\// {
      branch = substr($0, 19)
      if (branch != "") {
        print branch
      }
    }
  '
}

list_available_branches() {
  local occupied
  occupied="$(occupied_worktree_branches)"

  {
    git for-each-ref --sort=refname --format='%(refname:short)%09local' refs/heads
    git for-each-ref --sort=refname --format='%(refname:short)%09remote' refs/remotes/origin
  } | awk -F '\t' -v occupied="${occupied}" '
    BEGIN {
      split(occupied, occupied_lines, "\n")
      for (i in occupied_lines) {
        if (occupied_lines[i] != "") {
          occupied_branch[occupied_lines[i]] = 1
        }
      }
    }

    $1 == "origin/HEAD" {
      next
    }

    $2 == "remote" {
      sub(/^origin\//, "", $1)
    }

    $1 == "" || occupied_branch[$1] {
      next
    }

    seen[$1] {
      source[$1] = source[$1] "," $2
      next
    }

    {
      seen[$1] = 1
      source[$1] = $2
      branch[++count] = $1
    }

    END {
      for (i = 1; i <= count; i++) {
        print branch[i] "\t" source[branch[i]]
      }
    }
  '
}

select_branch() {
  local entries
  local selected
  local branch

  require_command fzf

  entries="$(
    {
      printf '<new>\ttype a new worktree branch name\n'
      list_available_branches
    } | awk -F '\t' '{ printf "%s\t%s\n", $1, $2 }'
  )"

  selected="$(
    printf '%s\n' "${entries}" | fzf \
      --ansi \
      --delimiter=$'\t' \
      --with-nth=1,2 \
      --prompt='Worktree branch > ' \
      --header='Select an unoccupied branch, or choose "new" to type a branch name.' \
      --select-1 \
      --exit-0
  )"

  if [[ -z "${selected}" ]]; then
    return 1
  fi

  branch="${selected%%$'\t'*}"
  if [[ "${branch}" != "<new>" ]]; then
    printf '%s\n' "${branch}"
    return
  fi

  printf 'New branch name: ' >&2
  IFS= read -r branch
  [[ -n "${branch}" ]] || fatal "new branch name is required" 2
  printf '%s\n' "${branch}"
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

  if [[ $# -eq 0 ]]; then
    branch="$(select_branch)"
  fi

  [[ $# -gt 1 ]] && fatal "expected exactly one BRANCH argument, got $#" 2
  if [[ $# -eq 1 ]]; then
    branch="$1"
  fi

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
