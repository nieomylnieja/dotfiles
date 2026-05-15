#!/usr/bin/env bash

set -euo pipefail

readonly PROG="${0##*/}"
readonly DEFAULT_THRESHOLD_CHARS=6000
readonly DEFAULT_HEAD_LINES=5
readonly DEFAULT_TAIL_LINES=3
readonly DEFAULT_NOTABLE_LINES=8
readonly DEFAULT_COMPACTION_MODE="deterministic"
readonly DEFAULT_COMPACTOR_MODEL="gpt-5.4-mini"
readonly DEFAULT_COMPACTOR_REASONING_EFFORT="low"
readonly DEFAULT_AGENT_INPUT_MAX_CHARS=120000
readonly DEFAULT_AGENT_TIMEOUT_SEC=75
readonly STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/codex/hooks"
readonly LOG_FILE="${STATE_DIR}/compact-tool-result.jsonl"

usage() {
  cat << EOF
Usage: ${PROG} [OPTION]...
Log compact summaries for large Codex PostToolUse results.

Reads a Codex PostToolUse hook JSON payload from stdin. When the tool response
is larger than CODEX_TOOL_RESULT_COMPACT_THRESHOLD_CHARS, writes a compact
summary record to ${LOG_FILE} and emits a short in-session status message.
Agent mode can optionally ask a bare Codex worker to produce the summary
before it is logged.

Environment:
  CODEX_TOOL_RESULT_COMPACT_THRESHOLD_CHARS  minimum extracted result size
                                             before a summary is logged
                                             (default: ${DEFAULT_THRESHOLD_CHARS})
  CODEX_TOOL_RESULT_COMPACT_MODE             agent or deterministic
                                             (default: ${DEFAULT_COMPACTION_MODE})
  CODEX_TOOL_RESULT_COMPACTOR_MODEL          bare worker model
                                             (default: ${DEFAULT_COMPACTOR_MODEL})
  CODEX_TOOL_RESULT_COMPACTOR_REASONING      bare worker reasoning effort
                                             (default: ${DEFAULT_COMPACTOR_REASONING_EFFORT})
  CODEX_TOOL_RESULT_COMPACT_AGENT_MAX_CHARS  max extracted output bytes sent to
                                             the bare worker
                                             (default: ${DEFAULT_AGENT_INPUT_MAX_CHARS})
  CODEX_TOOL_RESULT_COMPACT_AGENT_TIMEOUT    child worker timeout in seconds
                                             (default: ${DEFAULT_AGENT_TIMEOUT_SEC})

Options:
  -h, --help  display this help and exit

Exit status:
  0  success
  1  general error
  2  usage error
EOF
}

fatal() {
  echo "${PROG}: ERROR: $*" >&2
  exit "${2:-1}"
}

make_tmp_file() {
  local suffix="$1"
  local timestamp
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  printf '%s\n' "${TMPDIR:-/tmp}/${PROG}-${timestamp}-${RANDOM}-${suffix}"
}

cleanup_tmp_files() {
  local file
  for file in "${TMP_FILES[@]:-}"; do
    case "${file}" in
      "${TMPDIR:-/tmp}/${PROG}-"*)
        rm -rf "${file}"
        ;;
      *)
        ;;
    esac
  done
}

require_command() {
  local command_name="$1"
  command -v "${command_name}" > /dev/null 2>&1 || fatal "${command_name} is required"
}

positive_integer_or_default() {
  local value="$1"
  local default_value="$2"

  if [[ "${value}" =~ ^[1-9][0-9]*$ ]]; then
    printf '%s\n' "${value}"
    return 0
  fi

  printf '%s\n' "${default_value}"
}

extract_tool_response_text() {
  local input_file="$1"
  local output_file="$2"

  jq -r '
    def response_strings:
      if type == "string" then
        .
      elif type == "array" then
        .[] | response_strings
      elif type == "object" then
        (
          .stdout?,
          .stderr?,
          .output?,
          .text?,
          .content?,
          .message?,
          .result?,
          .data?
        )
        | select(. != null)
        | response_strings
      else
        empty
      end;

    .tool_response | response_strings
  ' "${input_file}" > "${output_file}"
}

select_notable_lines() {
  local input_file="$1"
  local max_lines="$2"
  local output_file="$3"

  awk -v max_lines="${max_lines}" '
    BEGIN {
      count = 0
    }
    {
      lower = tolower($0)
      if (lower ~ /(error|warn|fail|failed|failure|exception|panic|denied|not found|summary|passed|tests?|exit code|modified|created|deleted|todo|fixme)/) {
        print
        count += 1
      }
      if (count >= max_lines) {
        exit
      }
    }
  ' "${input_file}" > "${output_file}"
}

write_agent_prompt() {
  local tool_name="$1"
  local char_count="$2"
  local line_count="$3"
  local input_file="$4"
  local max_chars="$5"
  local output_file="$6"
  local included_chars="${char_count}"

  if ((char_count > max_chars)); then
    included_chars="${max_chars}"
  fi

  {
    cat << EOF
You are a bare Codex compaction worker. Summarize the tool result for retention
in the parent agent's conversation context.

Constraints:
- Preserve durable facts, decisions, exact paths, commands, error messages, counts,
  and test/build outcomes.
- Preserve line numbers only when they appear meaningful in the input.
- Drop bulk listings, repeated rows, full file bodies, progress noise, and other
  raw content that can be re-read or re-run.
- Do not explain your process.
- Return only the compacted retained context, in concise Markdown.
- Keep the answer under 1200 words unless the result contains many independent
  failures that need exact preservation.

Tool: ${tool_name}
Extracted result size: ${line_count} lines, ${char_count} bytes
Bytes included below: ${included_chars}
EOF

    if ((char_count > max_chars)); then
      cat << EOF
The extracted result was larger than the compaction worker input cap, so the
input below is truncated at ${max_chars} bytes. Say explicitly if the retained
context may be incomplete because of that truncation.
EOF
    fi

    printf '\n<tool_result>\n'
    head -c "${max_chars}" "${input_file}"
    printf '\n</tool_result>\n'
  } > "${output_file}"
}

slice_boundary_lines() {
  local input_file="$1"
  local line_count="$2"
  local output_file="$3"
  local head_lines="${DEFAULT_HEAD_LINES}"
  local tail_lines="${DEFAULT_TAIL_LINES}"
  local tail_start

  if ((line_count <= head_lines + tail_lines)); then
    sed -n '1,80p' "${input_file}" > "${output_file}"
    return 0
  fi

  sed -n "1,${head_lines}p" "${input_file}" > "${output_file}"
  printf '\n... [%s middle lines omitted by compact-tool-result] ...\n\n' \
    "$((line_count - head_lines - tail_lines))" >> "${output_file}"
  tail_start="$((line_count - tail_lines + 1))"
  sed -n "${tail_start},${line_count}p" "${input_file}" >> "${output_file}"
}

build_deterministic_summary() {
  local tool_name="$1"
  local char_count="$2"
  local line_count="$3"
  local notable_file="$4"
  local boundary_file="$5"

  printf 'The previous %s result was large (%s lines, %s bytes extracted).\n' \
    "${tool_name}" \
    "${line_count}" \
    "${char_count}"
  printf '%s ' 'Retain only durable findings, decisions, paths, errors, and commands needed later.'
  printf '%s\n\n' 'Do not carry forward the full raw output. Re-run or re-read exact content only when exact text is needed.'

  if [[ -s "${notable_file}" ]]; then
    printf 'Notable lines:\n'
    sed -n '1,40p' "${notable_file}"
    printf '\n\n'
  fi

  printf 'Boundary sample:\n'
  sed -n '1,40p' "${boundary_file}"
}

count_bytes_in_file() {
  local input_file="$1"

  wc -c < "${input_file}"
}

append_log_entry() {
  local input_file="$1"
  local tool_name="$2"
  local compaction_mode="$3"
  local char_count="$4"
  local line_count="$5"
  local summary_file="$6"
  local stored_byte_count="$7"
  local retained_byte_count="$8"
  local trimmed_byte_count="$9"
  local timestamp
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

  if ! mkdir -p "${STATE_DIR}" 2> /dev/null; then
    return 1
  fi

  jq -c -n \
    --arg timestamp "${timestamp}" \
    --arg session_id "$(jq -r '.session_id // ""' "${input_file}")" \
    --arg turn_id "$(jq -r '.turn_id // ""' "${input_file}")" \
    --arg tool_name "${tool_name}" \
    --arg compaction_mode "${compaction_mode}" \
    --argjson extracted_bytes "${char_count}" \
    --argjson extracted_lines "${line_count}" \
    --argjson stored_bytes "${stored_byte_count}" \
    --argjson retained_bytes "${retained_byte_count}" \
    --argjson trimmed_bytes "${trimmed_byte_count}" \
    --rawfile summary "${summary_file}" \
    '{
      timestamp: $timestamp,
      session_id: (if $session_id == "" then null else $session_id end),
      turn_id: (if $turn_id == "" then null else $turn_id end),
      tool_name: $tool_name,
      compaction_mode: $compaction_mode,
      extracted: {
        bytes: $extracted_bytes,
        lines: $extracted_lines
      },
      summary: {
        stored_bytes: $stored_bytes,
        retained_bytes: $retained_bytes,
        trimmed_bytes: $trimmed_bytes,
        text: ($summary | sub("\n$"; ""))
      }
    }' >> "${LOG_FILE}" 2> /dev/null
}

emit_system_message() {
  local tool_name="$1"
  local char_count="$2"
  local retained_byte_count="$3"
  local trimmed_byte_count="$4"
  local line_count="$5"
  local log_status="$6"
  local message="Compacted ${tool_name}: ${char_count}B -> ${retained_byte_count}B (-${trimmed_byte_count}B, ${line_count}l)"

  if [[ "${log_status}" != "logged" ]]; then
    message="${message}; state log unavailable"
  fi

  jq -n \
    --arg system_message "${message}" \
    '{systemMessage: $system_message}'
}

run_agent_compaction() {
  local tool_name="$1"
  local char_count="$2"
  local line_count="$3"
  local response_text_file="$4"
  local max_chars="$5"
  local prompt_file="$6"
  local output_file="$7"
  local stdout_file="$8"
  local stderr_file="$9"
  local bare_workspace="${10}"
  local timeout_sec="${11}"

  local model="${CODEX_TOOL_RESULT_COMPACTOR_MODEL:-${DEFAULT_COMPACTOR_MODEL}}"
  local reasoning_effort="${CODEX_TOOL_RESULT_COMPACTOR_REASONING:-${DEFAULT_COMPACTOR_REASONING_EFFORT}}"

  write_agent_prompt \
    "${tool_name}" \
    "${char_count}" \
    "${line_count}" \
    "${response_text_file}" \
    "${max_chars}" \
    "${prompt_file}"

  mkdir -p "${bare_workspace}"

  command -v timeout > /dev/null 2>&1 || return 1

  timeout "${timeout_sec}s" codex exec \
    --ignore-user-config \
    --ignore-rules \
    --skip-git-repo-check \
    --ephemeral \
    --color never \
    --cd "${bare_workspace}" \
    --model "${model}" \
    --config "model_reasoning_effort=\"${reasoning_effort}\"" \
    --config 'features.codex_hooks=false' \
    --config 'mcp_servers={}' \
    --config 'include_environment_context=false' \
    --config 'include_permissions_instructions=false' \
    --output-last-message "${output_file}" \
    - < "${prompt_file}" > "${stdout_file}" 2> "${stderr_file}"
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -*)
        fatal "unknown option: $1" 2
        ;;
      *)
        fatal "unexpected argument: $1" 2
        ;;
    esac
  done

  require_command jq
  require_command awk
  require_command head
  require_command sed
  require_command wc

  local threshold_chars
  threshold_chars="$(positive_integer_or_default \
    "${CODEX_TOOL_RESULT_COMPACT_THRESHOLD_CHARS:-}" \
    "${DEFAULT_THRESHOLD_CHARS}")"
  local agent_max_chars
  agent_max_chars="$(positive_integer_or_default \
    "${CODEX_TOOL_RESULT_COMPACT_AGENT_MAX_CHARS:-}" \
    "${DEFAULT_AGENT_INPUT_MAX_CHARS}")"
  local agent_timeout_sec
  agent_timeout_sec="$(positive_integer_or_default \
    "${CODEX_TOOL_RESULT_COMPACT_AGENT_TIMEOUT:-}" \
    "${DEFAULT_AGENT_TIMEOUT_SEC}")"

  local input_file
  local response_text_file
  local notable_file
  local boundary_file
  local summary_file
  local prompt_file
  local agent_output_file
  local agent_stdout_file
  local agent_stderr_file
  local bare_workspace
  input_file="$(make_tmp_file "input.json")"
  response_text_file="$(make_tmp_file "response.txt")"
  notable_file="$(make_tmp_file "notable.txt")"
  boundary_file="$(make_tmp_file "boundary.txt")"
  summary_file="$(make_tmp_file "summary.txt")"
  prompt_file="$(make_tmp_file "agent-prompt.txt")"
  agent_output_file="$(make_tmp_file "agent-output.txt")"
  agent_stdout_file="$(make_tmp_file "agent-stdout.txt")"
  agent_stderr_file="$(make_tmp_file "agent-stderr.txt")"
  bare_workspace="$(make_tmp_file "bare-workspace")"
  TMP_FILES=(
    "${input_file}"
    "${response_text_file}"
    "${notable_file}"
    "${boundary_file}"
    "${summary_file}"
    "${prompt_file}"
    "${agent_output_file}"
    "${agent_stdout_file}"
    "${agent_stderr_file}"
    "${bare_workspace}"
  )
  trap 'cleanup_tmp_files' EXIT

  cat > "${input_file}"

  jq -e '.hook_event_name == "PostToolUse"' "${input_file}" > /dev/null \
    || exit 0

  extract_tool_response_text "${input_file}" "${response_text_file}"

  local char_count
  local line_count
  char_count="$(wc -c < "${response_text_file}")"
  line_count="$(wc -l < "${response_text_file}")"

  if ((char_count < threshold_chars)); then
    exit 0
  fi

  local tool_name
  tool_name="$(jq -r '.tool_name // "unknown-tool"' "${input_file}")"

  local stored_byte_count=0
  local retained_byte_count=0
  local trimmed_byte_count=0
  local log_status="unavailable"
  local compaction_mode="${CODEX_TOOL_RESULT_COMPACT_MODE:-${DEFAULT_COMPACTION_MODE}}"
  if [[ "${compaction_mode}" == "agent" ]] && command -v codex > /dev/null 2>&1; then
    if run_agent_compaction \
      "${tool_name}" \
      "${char_count}" \
      "${line_count}" \
      "${response_text_file}" \
      "${agent_max_chars}" \
      "${prompt_file}" \
      "${agent_output_file}" \
      "${agent_stdout_file}" \
      "${agent_stderr_file}" \
      "${bare_workspace}" \
      "${agent_timeout_sec}"; then
      local agent_summary
      agent_summary="$(sed -n '1,220p' "${agent_output_file}")"
      if [[ -n "${agent_summary//[[:space:]]/}" ]]; then
        {
          printf 'The previous %s result was compacted by a bare Codex worker.\n\n' "${tool_name}"
          printf '%s\n' "${agent_summary}"
        } > "${summary_file}"
        stored_byte_count="$(count_bytes_in_file "${summary_file}")"
        retained_byte_count="${stored_byte_count}"
        if ((retained_byte_count > char_count)); then
          retained_byte_count="${char_count}"
        fi
        trimmed_byte_count="$((char_count - retained_byte_count))"
        if ((trimmed_byte_count < 0)); then
          trimmed_byte_count=0
        fi
        if append_log_entry \
          "${input_file}" \
          "${tool_name}" \
          "agent" \
          "${char_count}" \
          "${line_count}" \
          "${summary_file}" \
          "${stored_byte_count}" \
          "${retained_byte_count}" \
          "${trimmed_byte_count}"; then
          log_status="logged"
        fi
        emit_system_message \
          "${tool_name}" \
          "${char_count}" \
          "${retained_byte_count}" \
          "${trimmed_byte_count}" \
          "${line_count}" \
          "${log_status}"
        exit 0
      fi
    fi
  fi

  select_notable_lines "${response_text_file}" "${DEFAULT_NOTABLE_LINES}" "${notable_file}"
  slice_boundary_lines "${response_text_file}" "${line_count}" "${boundary_file}"
  build_deterministic_summary \
    "${tool_name}" \
    "${char_count}" \
    "${line_count}" \
    "${notable_file}" \
    "${boundary_file}" > "${summary_file}"
  stored_byte_count="$(count_bytes_in_file "${summary_file}")"
  retained_byte_count="${stored_byte_count}"
  if ((retained_byte_count > char_count)); then
    retained_byte_count="${char_count}"
  fi
  trimmed_byte_count="$((char_count - retained_byte_count))"
  if ((trimmed_byte_count < 0)); then
    trimmed_byte_count=0
  fi
  if append_log_entry \
    "${input_file}" \
    "${tool_name}" \
    "deterministic" \
    "${char_count}" \
    "${line_count}" \
    "${summary_file}" \
    "${stored_byte_count}" \
    "${retained_byte_count}" \
    "${trimmed_byte_count}"; then
    log_status="logged"
  fi
  emit_system_message \
    "${tool_name}" \
    "${char_count}" \
    "${retained_byte_count}" \
    "${trimmed_byte_count}" \
    "${line_count}" \
    "${log_status}"
}

main "$@"
