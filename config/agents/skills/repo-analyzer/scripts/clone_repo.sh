#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'clone_repo.sh - create or reuse a managed read-only repository clone' \
    '' \
    'Usage:' \
    '  clone_repo.sh --url URL [--ref REVISION]' \
    '  clone_repo.sh --url URL --refresh --ref REVISION' \
    '' \
    'Options:' \
    '  --url URL       HTTPS URL, git@ SSH URL, or GitHub owner/repo' \
    '  --ref REVISION  Branch, tag, or commit to inspect' \
    '  --branch NAME   Deprecated alias for --ref' \
    '  --refresh       Fetch --ref in an existing managed clone' \
    '  --base PATH     Override the managed clone root' \
    '  --help          Show this help' \
    '' \
    'Existing clones are reused without network access.' \
    'The command never runs git pull.'
}

die() {
  printf 'clone_repo.sh: %s\n' "${1}" >&2
  exit 1
}

require_value() {
  local flag="$1"
  local value="${2:-}"

  [[ -n "${value}" ]] || die "${flag} requires a value"
}

valid_segment() {
  local value="$1"

  [[ "${value}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] &&
    [[ "${value}" != "." ]] &&
    [[ "${value}" != ".." ]]
}

parse_repository() {
  local input="$1"
  local short_pattern='^([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)$'
  local https_pattern='^https?://([A-Za-z0-9.-]+)/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)/?$'
  local ssh_pattern='^git@([A-Za-z0-9.-]+):([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)$'

  input="${input%.git}"

  if [[ "${input}" =~ ${short_pattern} ]]; then
    platform="github.com"
    organization="${BASH_REMATCH[1]}"
    repository="${BASH_REMATCH[2]}"
    clone_url="https://github.com/${organization}/${repository}.git"
  elif [[ "${input}" =~ ${https_pattern} ]]; then
    platform="${BASH_REMATCH[1],,}"
    organization="${BASH_REMATCH[2]}"
    repository="${BASH_REMATCH[3]}"
    clone_url="${input}.git"
  elif [[ "${input}" =~ ${ssh_pattern} ]]; then
    platform="${BASH_REMATCH[1],,}"
    organization="${BASH_REMATCH[2]}"
    repository="${BASH_REMATCH[3]}"
    clone_url="${input}.git"
  else
    die "unsupported repository URL"
  fi

  valid_segment "${platform}" || die "invalid repository host: ${platform}"
  valid_segment "${organization}" || die "invalid repository owner: ${organization}"
  valid_segment "${repository}" || die "invalid repository name: ${repository}"
}

checkout_ref() {
  local path="$1"
  local revision="$2"
  local target=""

  if [[ -n "$(git -C "${path}" status --porcelain)" ]]; then
    die "managed clone has local changes: ${path}"
  fi

  if [[ "${refresh}" == "true" ]]; then
    git -C "${path}" fetch --depth 1 origin "${revision}"
    target="FETCH_HEAD"
  elif git -C "${path}" rev-parse --verify --quiet "${revision}^{commit}" >/dev/null; then
    target="${revision}^{commit}"
  elif git -C "${path}" rev-parse --verify --quiet "origin/${revision}^{commit}" >/dev/null; then
    target="origin/${revision}^{commit}"
  else
    die "ref is not available in the managed clone: ${revision}; use --refresh --ref ${revision}"
  fi

  git -C "${path}" checkout --detach "${target}"
}

assert_repository_identity() {
  local path="$1"
  local expected_platform="${platform}"
  local expected_organization="${organization}"
  local expected_repository="${repository}"
  local expected_clone_url="${clone_url}"
  local origin_url=""

  if ! origin_url="$(git -C "${path}" config --get remote.origin.url)" ||
    [[ -z "${origin_url}" ]]; then
    die "managed clone has no origin URL: ${path}"
  fi

  parse_repository "${origin_url}"
  if [[ "${expected_platform}" == "github.com" ]]; then
    if [[ "${platform,,}/${organization,,}/${repository,,}" != "${expected_platform,,}/${expected_organization,,}/${expected_repository,,}" ]]; then
      die "managed clone origin does not match requested repository: ${path}"
    fi
  elif [[ "${platform}/${organization}/${repository}" != "${expected_platform}/${expected_organization}/${expected_repository}" ]]; then
    die "managed clone origin does not match requested repository: ${path}"
  fi

  platform="${expected_platform}"
  organization="${expected_organization}"
  repository="${expected_repository}"
  clone_url="${expected_clone_url}"
}

cleanup_temporary_clone() {
  if [[ -n "${temporary_clone}" && -d "${temporary_clone}" ]]; then
    rm -rf -- "${temporary_clone}"
  fi
}

clone_repository() {
  local timestamp
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  temporary_clone="$(mktemp -d "${repository_path}.tmp.${timestamp}.XXXXXX")"

  if [[ -n "${requested_ref}" ]]; then
    git -C "${temporary_clone}" init
    git -C "${temporary_clone}" remote add origin "${clone_url}"
    if ! git -C "${temporary_clone}" fetch --depth 1 origin "${requested_ref}"; then
      die "failed to fetch ref from repository: ${requested_ref}"
    fi
    git -C "${temporary_clone}" checkout --detach FETCH_HEAD
  else
    git clone --depth 1 "${clone_url}" "${temporary_clone}"
  fi

  if ! mv -T -- "${temporary_clone}" "${repository_path}"; then
    die "managed clone destination appeared during clone: ${repository_path}"
  fi
  temporary_clone=""
}

repository_url=""
requested_ref=""
refresh="false"
clone_base="${XDG_DATA_HOME:-${HOME}/.local/share}/agents/repositories"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --url)
    require_value "$1" "${2:-}"
    repository_url="$2"
    shift 2
    ;;
  --ref | --branch)
    require_value "$1" "${2:-}"
    requested_ref="$2"
    shift 2
    ;;
  --refresh)
    refresh="true"
    shift
    ;;
  --base)
    require_value "$1" "${2:-}"
    clone_base="$2"
    shift 2
    ;;
  --help)
    usage
    exit 0
    ;;
  *)
    die "unknown argument: $1"
    ;;
  esac
done

[[ -n "${repository_url}" ]] || die "--url is required"
if [[ "${refresh}" == "true" && -z "${requested_ref}" ]]; then
  die "--refresh requires --ref"
fi

platform=""
organization=""
repository=""
clone_url=""
temporary_clone=""
trap cleanup_temporary_clone EXIT
parse_repository "${repository_url}"

mkdir -p "${clone_base}/${platform}/${organization}"
clone_base="$(cd "${clone_base}" && pwd -P)"
repository_path="${clone_base}/${platform}/${organization}/${repository}"

if [[ -e "${repository_path}" && ! -d "${repository_path}/.git" ]]; then
  die "destination exists but is not a Git repository: ${repository_path}"
fi

if [[ -d "${repository_path}/.git" ]]; then
  assert_repository_identity "${repository_path}"
  if [[ -n "$(git -C "${repository_path}" status --porcelain)" ]]; then
    die "managed clone has local changes: ${repository_path}"
  fi
  if [[ -n "${requested_ref}" ]]; then
    checkout_ref "${repository_path}" "${requested_ref}"
  fi
else
  clone_repository
fi

git -C "${repository_path}" rev-parse --verify HEAD >/dev/null
printf '%s\n' "${repository_path}"
