#!/usr/bin/env bash

set -euo pipefail

readonly PROG="${0##*/}"
readonly HARNESSES=("claude-code" "opencode" "codex")

usage() {
  cat << EOF
Usage: ${PROG} [OPTIONS]

Generate harness-specific agent definitions from source agents.

Reads source agent markdown files from config/agents/agents/ and generates
harness-specific copies under:
- ~/.claude/agents/
- \$XDG_CONFIG_HOME/opencode/agents/ (defaults to ~/.config/opencode/agents/)
- ~/.codex/agents/

Each source agent contains a harness-config frontmatter block with per-harness
overrides. Common fields are merged with harness-specific fields; harness fields
take precedence. Codex agents are emitted as standalone TOML files using the
source agent body as developer instructions.

Options:
  --source DIR  source agents directory (default: config/agents/agents)
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

# make_tmp_file SUFFIX
# Returns a timestamped temporary file path.
make_tmp_file() {
  local suffix="$1"
  local timestamp
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  printf '%s\n' "${TMPDIR:-/tmp}/${PROG}-${timestamp}-${RANDOM}-${suffix}"
}

# harness_output_dir HARNESS
# Returns the output directory for a given harness.
harness_output_dir() {
  local harness="$1"
  case "${harness}" in
    claude-code) echo "${HOME}/.claude/agents" ;;
    opencode) echo "${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/agents" ;;
    codex) echo "${HOME}/.codex/agents" ;;
    *) fatal "unknown harness: ${harness}" ;;
  esac
}

# extract_frontmatter SOURCE_FILE OUT_FILE
# Writes the YAML frontmatter content without --- delimiters.
extract_frontmatter() {
  local source_file="$1"
  local out_file="$2"

  awk '
    BEGIN {
      fm_count = 0
    }

    /^---$/ {
      fm_count++
      next
    }

    fm_count == 1 { print }
    fm_count >= 2 { exit }
  ' "${source_file}" > "${out_file}"
}

# extract_body SOURCE_FILE OUT_FILE
# Writes the Markdown body after the frontmatter.
extract_body() {
  local source_file="$1"
  local out_file="$2"

  awk '
    BEGIN {
      fm_count = 0
    }

    /^---$/ {
      fm_count++
      next
    }

    fm_count < 2 {
      next
    }

    { print }
  ' "${source_file}" > "${out_file}"
}

# yaml_read YAML_FILE FILTER
# Reads a value from a YAML document using yq.
yaml_read() {
  local yaml_file="$1"
  local filter="$2"

  yq -r "${filter} // empty" "${yaml_file}"
}

# yaml_has YAML_FILE FILTER
# Returns success when the given YAML node exists and is non-null.
yaml_has() {
  local yaml_file="$1"
  local filter="$2"

  yq -e "${filter} != null" "${yaml_file}" > /dev/null
}

# write_generated_file OUTPUT_FILE TMP_FILE
# Writes generated content if it changed.
write_generated_file() {
  local output_file="$1"
  local tmp_file="$2"

  if [[ -f "${output_file}" ]] && cmp -s "${output_file}" "${tmp_file}"; then
    rm -f "${tmp_file}"
    return 0
  fi

  mkdir -p "$(dirname "${output_file}")"
  mv "${tmp_file}" "${output_file}"
}

# generate_markdown_agent SOURCE_FILE HARNESS
# Generates a harness-specific Markdown agent file.
generate_markdown_agent() {
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
      in_hc = 0; in_target = 0
    }

    /^---$/ {
      fm_count++
      if (fm_count == 1) { in_fm = 1; print; next }
      if (fm_count == 2) {
        in_fm = 0
        for (i = 1; i <= hf_count; i++) {
          print harness_fields[i]
        }
        print
        next
      }
    }

    in_fm == 0 { print; next }

    /^harness-config:/ {
      in_hc = 1
      next
    }

    in_hc == 1 {
      if (/^[^ ]/) {
        in_hc = 0
        in_target = 0
        print
        next
      }

      if (/^  [^ ]/) {
        harness_key = $0
        sub(/^  /, "", harness_key)
        sub(/:.*$/, "", harness_key)
        if (harness_key == harness) {
          in_target = 1
        } else {
          in_target = 0
        }
        next
      }

      if (in_target == 1 && /^    /) {
        line = $0
        sub(/^    /, "", line)
        hf_count++
        harness_fields[hf_count] = line
        next
      }

      next
    }

    { print }
  ' "${source_file}")"

  if [[ -z "${content}" ]]; then
    warn "$(basename "${source_file}"): generation produced empty output; skipping"
    return 0
  fi

  local tmp_file
  tmp_file="$(make_tmp_file "${harness}.md")"
  printf '%s\n' "${content}" > "${tmp_file}"
  write_generated_file "${out_file}" "${tmp_file}"
}

# generate_codex_agent SOURCE_FILE
# Generates a Codex custom-agent TOML file.
generate_codex_agent() {
  local source_file="$1"
  local basename
  basename="$(basename "${source_file}" .md)"

  local out_dir
  out_dir="$(harness_output_dir "codex")"
  local out_file="${out_dir}/${basename}.toml"

  local frontmatter_file
  frontmatter_file="$(make_tmp_file "frontmatter.yaml")"
  local body_file
  body_file="$(make_tmp_file "body.md")"
  local tmp_file
  tmp_file="$(make_tmp_file "${basename}.toml")"

  extract_frontmatter "${source_file}" "${frontmatter_file}"
  extract_body "${source_file}" "${body_file}"

  local name
  name="$(yaml_read "${frontmatter_file}" '.name')"
  [[ -n "${name}" ]] || fatal "${source_file}: missing frontmatter field 'name'"

  local description
  description="$(yaml_read "${frontmatter_file}" '.description')"
  [[ -n "${description}" ]] || fatal "${source_file}: missing frontmatter field 'description'"

  local developer_instructions
  developer_instructions="$(sed '1{/^$/d;}' "${body_file}")"
  [[ -n "${developer_instructions}" ]] || fatal "${source_file}: missing agent body"

  local model
  model="$(yaml_read "${frontmatter_file}" '."harness-config".codex.model')"

  local model_reasoning_effort
  model_reasoning_effort="$(yaml_read "${frontmatter_file}" '."harness-config".codex.model_reasoning_effort')"

  local model_verbosity
  model_verbosity="$(yaml_read "${frontmatter_file}" '."harness-config".codex.model_verbosity')"

  local sandbox_mode
  sandbox_mode="$(yaml_read "${frontmatter_file}" '."harness-config".codex.sandbox_mode')"

  # shellcheck disable=SC2016
  tomlq -t -n \
    --arg name "${name}" \
    --arg description "${description}" \
    --arg developer_instructions "${developer_instructions}" \
    --arg model "${model}" \
    --arg model_reasoning_effort "${model_reasoning_effort}" \
    --arg model_verbosity "${model_verbosity}" \
    --arg sandbox_mode "${sandbox_mode}" \
    '{
      name: $name,
      description: $description,
      developer_instructions: $developer_instructions
    }
    | if $model != "" then . + {model: $model} else . end
    | if $model_reasoning_effort != "" then . + {model_reasoning_effort: $model_reasoning_effort} else . end
    | if $model_verbosity != "" then . + {model_verbosity: $model_verbosity} else . end
    | if $sandbox_mode != "" then . + {sandbox_mode: $sandbox_mode} else . end' \
    > "${tmp_file}"

  tomlq '.' "${tmp_file}" > /dev/null || fatal "${source_file}: generated invalid Codex TOML"

  write_generated_file "${out_file}" "${tmp_file}"

  rm -f "${frontmatter_file}" "${body_file}"
}

# generate_agent SOURCE_FILE HARNESS
# Dispatches to the appropriate harness generator.
generate_agent() {
  local source_file="$1"
  local harness="$2"

  case "${harness}" in
    codex) generate_codex_agent "${source_file}" ;;
    *) generate_markdown_agent "${source_file}" "${harness}" ;;
  esac
}

main() {
  local root
  root="${DOTFILES:-${HOME}/.dotfiles}"

  local source_dir="${root}/config/agents/agents"

  command -v yq > /dev/null 2>&1 || fatal "yq is required"
  command -v tomlq > /dev/null 2>&1 || fatal "tomlq is required"

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

  log "sync complete (${count} source agents processed)"
}

main "$@"
