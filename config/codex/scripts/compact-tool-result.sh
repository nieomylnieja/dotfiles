#!/usr/bin/env bash

set -euo pipefail

readonly PROG="${0##*/}"
readonly DEFAULT_THRESHOLD_CHARS=8000
readonly DEFAULT_HEAD_LINES=8
readonly DEFAULT_TAIL_LINES=4
readonly DEFAULT_NOTABLE_LINES=12
readonly DEFAULT_MAX_CONTEXT_CHARS=1800
readonly DEFAULT_COMPACTION_MODE="deterministic"
readonly DEFAULT_COMPACTOR_MODEL="gpt-5.4-mini"
readonly DEFAULT_COMPACTOR_REASONING_EFFORT="low"
readonly DEFAULT_AGENT_INPUT_MAX_CHARS=120000
readonly DEFAULT_AGENT_TIMEOUT_SEC=75

usage() {
  cat << EOF
Usage: ${PROG} [OPTION]...
Emit compact model context for large Codex PostToolUse results.

Reads a Codex PostToolUse hook JSON payload from stdin. When the tool response
is larger than CODEX_TOOL_RESULT_COMPACT_THRESHOLD_CHARS, emits bounded
model-visible hook context. Agent mode can optionally ask a bare Codex worker
to compact the result before applying the output cap.

Environment:
  CODEX_TOOL_RESULT_COMPACT_THRESHOLD_CHARS  minimum extracted result size
                                             before compaction context is emitted
                                             (default: ${DEFAULT_THRESHOLD_CHARS})
  CODEX_TOOL_RESULT_COMPACT_MAX_CONTEXT_CHARS
                                             max model-visible hook context bytes
                                             emitted by this script
                                             (default: ${DEFAULT_MAX_CONTEXT_CHARS})
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

truncate_text() {
  local input_text="$1"
  local max_chars="$2"
  local marker
  marker=$'\n[compact-tool-result: truncated hook context]'

  if ((${#input_text} <= max_chars)); then
    printf '%s\n' "${input_text}"
    return 0
  fi

  if ((${#marker} >= max_chars)); then
    printf '%s\n' "${input_text:0:max_chars}"
    return 0
  fi

  local retained_chars="$((max_chars - ${#marker}))"
  printf '%s\n' "${input_text:0:retained_chars}${marker}"
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

emit_context_json() {
  local summary_text="$1"
  local max_context_chars="$2"
  local truncated_summary

  truncated_summary="$(truncate_text "${summary_text}" "${max_context_chars}")"

  jq -n \
    --arg summary_text "${truncated_summary}" \
    '{
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: $summary_text
      }
    }'
}

emit_deterministic_compaction_context() {
  local tool_name="$1"
  local char_count="$2"
  local line_count="$3"
  local notable_file="$4"
  local boundary_file="$5"
  local max_context_chars="$6"
  local notable_text
  local boundary_text

  notable_text="$(sed -n '1,40p' "${notable_file}")"
  boundary_text="$(sed -n '1,40p' "${boundary_file}")"

  local summary_text
  summary_text="$(jq -n -r \
    --arg tool_name "${tool_name}" \
    --arg char_count "${char_count}" \
    --arg line_count "${line_count}" \
    --arg notable_text "${notable_text}" \
    --arg boundary_text "${boundary_text}" \
    '"<tool_result_compaction>\n"
      + "The previous " + $tool_name + " result was large ("
      + $line_count + " lines, " + $char_count + " bytes extracted).\n"
      + "After processing it, retain only durable findings, decisions, paths, errors, and commands needed later. "
      + "Do not carry forward the full raw output. Re-run or re-read exact content only when exact text is needed.\n\n"
      + (if ($notable_text | length) > 0 then "Notable lines:\n" + $notable_text + "\n\n" else "" end)
      + "Boundary sample:\n"
      + $boundary_text
      + "\n</tool_result_compaction>"')"

  emit_context_json "${summary_text}" "${max_context_chars}"
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
  local max_context_chars
  max_context_chars="$(positive_integer_or_default \
    "${CODEX_TOOL_RESULT_COMPACT_MAX_CONTEXT_CHARS:-}" \
    "${DEFAULT_MAX_CONTEXT_CHARS}")"
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
  local prompt_file
  local agent_output_file
  local agent_stdout_file
  local agent_stderr_file
  local bare_workspace
  input_file="$(make_tmp_file "input.json")"
  response_text_file="$(make_tmp_file "response.txt")"
  notable_file="$(make_tmp_file "notable.txt")"
  boundary_file="$(make_tmp_file "boundary.txt")"
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
        emit_context_json "<tool_result_compaction>
The previous ${tool_name} result was compacted by a bare Codex worker.

${agent_summary}
</tool_result_compaction>" "${max_context_chars}"
        exit 0
      fi
    fi
  fi

  select_notable_lines "${response_text_file}" "${DEFAULT_NOTABLE_LINES}" "${notable_file}"
  slice_boundary_lines "${response_text_file}" "${line_count}" "${boundary_file}"
  emit_deterministic_compaction_context \
    "${tool_name}" \
    "${char_count}" \
    "${line_count}" \
    "${notable_file}" \
    "${boundary_file}" \
    "${max_context_chars}"
}

main "$@"
