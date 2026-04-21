#!/usr/bin/env bash

set -euo pipefail

readonly PROG="${0##*/}"
readonly HARNESSES=("claude-code" "opencode")

usage() {
  cat << EOF
Usage: ${PROG} [OPTIONS]

Generate harness-specific agent definitions from source agents.

Reads source agent markdown files from config/agents/agents/ and generates
harness-specific copies under config/claude/agents/ and config/opencode/agents/.

Each source agent contains a harness-config frontmatter block with per-harness
overrides. Common fields are merged with harness-specific fields; harness fields
take precedence.

Options:
  --source DIR  source agents directory (default: config/agents/agents)
  --dry-run     print what would change, do not write files
  -h, --help    display this help and exit

Exit status:
  0  success
  1  general error
  2  usage error
EOF
}

log() { echo "${PROG}: $*" >&2; }
warn() { echo "${PROG}: WARNING: $*" >&2; }
fatal() {
  echo "${PROG}: ERROR: $*" >&2
  exit "${2:-1}"
}

# harness_output_dir HARNESS
# Returns the output directory for a given harness.
harness_output_dir() {
  local harness="$1"
  case "${harness}" in
    claude-code) echo "${root}/config/claude/agents" ;;
    opencode) echo "${root}/config/opencode/agents" ;;
    *) fatal "unknown harness: ${harness}" ;;
  esac
}

# generate_agent SOURCE_FILE HARNESS
# Generates a harness-specific agent file by preserving original YAML formatting.
# Strips the harness-config block and injects the target harness's fields.
generate_agent() {
  local source_file="$1"
  local harness="$2"
  local basename
  basename="$(basename "${source_file}")"

  local out_dir
  out_dir="$(harness_output_dir "${harness}")"
  local out_file="${out_dir}/${basename}"

  local content
  content="$(awk -v harness="${harness}" '
    BEGIN {
      in_fm = 0; fm_count = 0
      in_hc = 0; in_target = 0; in_other = 0
      found_target = 0
    }

    /^---$/ {
      fm_count++
      if (fm_count == 1) { in_fm = 1; print; next }
      if (fm_count == 2) {
        in_fm = 0
        # Emit collected harness fields before closing ---
        for (i = 1; i <= hf_count; i++) {
          print harness_fields[i]
        }
        print
        next
      }
    }

    in_fm == 0 { print; next }

    # Inside frontmatter: detect harness-config block
    /^harness-config:/ {
      in_hc = 1
      next
    }

    in_hc == 1 {
      # Top-level key (not indented or less indented) ends harness-config
      if (/^[^ ]/) {
        in_hc = 0; in_target = 0; in_other = 0
        print
        next
      }

      # Harness key line: "  <name>:"
      if (/^  [^ ]/) {
        harness_key = $0
        sub(/^  /, "", harness_key)
        sub(/:.*$/, "", harness_key)
        if (harness_key == harness) {
          in_target = 1; in_other = 0; found_target = 1
        } else {
          in_target = 0; in_other = 1
        }
        next
      }

      # Field under a harness key: "    key: value"
      if (in_target == 1 && /^    /) {
        line = $0
        sub(/^    /, "", line)
        hf_count++
        harness_fields[hf_count] = line
        next
      }

      next
    }

    # Regular frontmatter line (not part of harness-config)
    { print }
  ' "${source_file}")"

  if [[ -z "${content}" ]]; then
    warn "${basename}: generation produced empty output; skipping"
    return 0
  fi

  if [[ "${dry_run}" == "1" ]]; then
    if [[ ! -f "${out_file}" ]] || ! cmp -s "${out_file}" <(printf '%s\n' "${content}"); then
      log "would write ${out_file}"
    fi
    return 0
  fi

  mkdir -p "${out_dir}"
  printf '%s\n' "${content}" > "${out_file}"
}

main() {
  local root
  root="${DOTFILES:-${HOME}/.dotfiles}"

  local source_dir="${root}/config/agents/agents"
  local dry_run="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      --source)
        [[ $# -lt 2 ]] && fatal "--source requires an argument" 2
        source_dir="$2"
        shift 2
        ;;
      --source=*)
        source_dir="${1#*=}"
        shift
        ;;
      --dry-run)
        dry_run="1"
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

  [[ -d "${source_dir}" ]] || fatal "source directory not found: ${source_dir}"

  local count=0
  local source_file
  for source_file in "${source_dir}"/*.md; do
    [[ -f "${source_file}" ]] || continue

    local harness
    for harness in "${HARNESSES[@]}"; do
      generate_agent "${source_file}" "${harness}"
    done

    ((count += 1))
  done

  if [[ "${count}" -eq 0 ]]; then
    warn "no agent source files found in ${source_dir}"
  fi

  if [[ "${dry_run}" == "1" ]]; then
    log "dry-run complete (${count} source agents processed)"
  else
    log "sync complete (${count} source agents processed)"
  fi
}

main "$@"
