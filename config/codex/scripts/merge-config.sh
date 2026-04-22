#!/usr/bin/env bash

set -euo pipefail

readonly PROG="${0##*/}"
TMP_FILES=()

usage() {
  cat << EOF
Usage: ${PROG} [OPTION]...
Merge the versioned Codex config into ~/.codex/config.toml.

Reads the versioned config from this repository and overlays it onto the live
Codex config at ~/.codex/config.toml. Existing local-only keys are preserved,
while keys from the versioned config take precedence.

Options:
  --source FILE  versioned config to apply (default: ../config.toml)
  --target FILE  live config to update (default: ~/.codex/config.toml)
  -h, --help     display this help and exit

Exit status:
  0  success
  1  general error
  2  usage error
EOF
}

log() { echo "${PROG}: $*" >&2; }
fatal() {
  echo "${PROG}: ERROR: $*" >&2
  exit "${2:-1}"
}

cleanup_tmp_files() {
  local file
  for file in "${TMP_FILES[@]:-}"; do
    rm -f "${file}"
  done
}

# make_tmp_file SUFFIX
# Returns a timestamped temporary file path.
make_tmp_file() {
  local suffix="$1"
  local timestamp
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  printf '%s\n' "${TMPDIR:-/tmp}/${PROG}-${timestamp}-${RANDOM}-${suffix}"
}

# resolve_path PATH
# Prints the physical path when it exists.
resolve_path() {
  local path="$1"
  readlink -f "${path}"
}

# extract_schema_comment SOURCE_FILE
# Prints the leading #:schema comment if present.
extract_schema_comment() {
  local source_file="$1"
  awk '
    /^#:schema / {
      print
      exit
    }
  ' "${source_file}"
}

# write_merged_config SOURCE_FILE TARGET_FILE OUTPUT_FILE
# Writes the final config, preserving the source schema comment.
write_merged_config() {
  local source_file="$1"
  local target_file="$2"
  local output_file="$3"
  local schema_comment
  schema_comment="$(extract_schema_comment "${source_file}")"

  if [[ -n "${schema_comment}" ]]; then
    printf '%s\n' "${schema_comment}" > "${output_file}"
    tomlq -t -s '.[0] * .[1]' "${target_file}" "${source_file}" >> "${output_file}"
    return 0
  fi

  tomlq -t -s '.[0] * .[1]' "${target_file}" "${source_file}" > "${output_file}"
}

main() {
  umask 077

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  local source_file="${script_dir}/../config.toml"
  local target_file="${HOME}/.codex/config.toml"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      --source)
        [[ $# -lt 2 ]] && fatal "--source requires an argument" 2
        source_file="$2"
        shift 2
        ;;
      --source=*)
        source_file="${1#*=}"
        shift
        ;;
      --target)
        [[ $# -lt 2 ]] && fatal "--target requires an argument" 2
        target_file="$2"
        shift 2
        ;;
      --target=*)
        target_file="${1#*=}"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        fatal "unknown option: $1" 2
        ;;
      *)
        fatal "unexpected argument: $1" 2
        ;;
    esac
  done

  command -v tomlq > /dev/null 2>&1 || fatal "tomlq is required"
  [[ -f "${source_file}" ]] || fatal "source config not found: ${source_file}"

  mkdir -p "$(dirname "${target_file}")"

  local target_source_path=""
  local source_path
  source_path="$(resolve_path "${source_file}")"
  if [[ -e "${target_file}" ]]; then
    target_source_path="$(resolve_path "${target_file}")"
  fi

  local local_file
  local merged_file
  local validated_file
  local source_validated_file
  local target_validated_file
  local_file="$(make_tmp_file "local.toml")"
  merged_file="$(make_tmp_file "merged.toml")"
  validated_file="$(make_tmp_file "validated.toml")"
  source_validated_file="$(make_tmp_file "source-validated.toml")"
  target_validated_file="$(make_tmp_file "target-validated.toml")"
  TMP_FILES=(
    "${local_file}"
    "${merged_file}"
    "${validated_file}"
    "${source_validated_file}"
    "${target_validated_file}"
  )
  trap 'cleanup_tmp_files' EXIT

  tomlq '.' "${source_file}" > "${source_validated_file}" \
    || fatal "invalid source config: ${source_file}"

  if [[ -e "${target_file}" ]]; then
    if [[ -n "${target_source_path}" ]] && [[ "${target_source_path}" == "${source_path}" ]]; then
      printf '' > "${local_file}"
    else
      tomlq '.' "${target_file}" > "${target_validated_file}" \
        || fatal "invalid target config: ${target_file}"
      cp "${target_file}" "${local_file}"
    fi
  else
    printf '' > "${local_file}"
  fi

  write_merged_config "${source_file}" "${local_file}" "${merged_file}"
  tomlq '.' "${merged_file}" > "${validated_file}" \
    || fatal "generated invalid TOML for ${target_file}"

  if [[ -L "${target_file}" ]]; then
    rm -f "${target_file}"
  fi

  if [[ -f "${target_file}" ]] && cmp -s "${target_file}" "${merged_file}"; then
    log "config unchanged"
    return 0
  fi

  mv "${merged_file}" "${target_file}"
  log "wrote ${target_file}"
}

main "$@"
