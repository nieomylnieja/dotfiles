#!/usr/bin/env bash

set -euo pipefail

readonly PROG="${0##*/}"
readonly DEFAULT_THRESHOLD_CHARS=6000
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
The hook always asks a bare Codex worker to produce the summary before it is
logged.

Environment:
  CODEX_TOOL_RESULT_COMPACT_THRESHOLD_CHARS  minimum extracted result size
                                             before a summary is logged
                                             (default: ${DEFAULT_THRESHOLD_CHARS})
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

extract_bash_command_text() {
  local input_file="$1"
  local output_file="$2"

  jq -r '
    (.tool_input? // empty) as $input
    | [
        $input.cmd?,
        $input.command?,
        $input.shell_command?,
        $input.args?.cmd?,
        $input.args?.command?
      ]
    | map(select(type == "string" and length > 0))
    | .[0] // empty
  ' "${input_file}" > "${output_file}"
}

references_markdown_file() {
  local input_file="$1"

  jq -e '
    def input_strings:
      if type == "string" then
        .
      elif type == "array" then
        .[] | input_strings
      elif type == "object" then
        .[] | input_strings
      else
        empty
      end;

    .tool_input? // empty
    | input_strings
    | select(test("[^[:space:][:cntrl:]][.](md|markdown)([^[:alnum:]_]|$)"; "i"))
  ' "${input_file}" > /dev/null
}

write_agent_prompt() {
  local tool_name="$1"
  local char_count="$2"
  local line_count="$3"
  local command_file="$4"
  local input_file="$5"
  local max_chars="$6"
  local output_file="$7"
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

    if [[ -s "${command_file}" ]]; then
      printf '\nExact bash command:\n```bash\n'
      cat "${command_file}"
      printf '```\n'
    fi

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

count_bytes_in_file() {
  local input_file="$1"

  wc -c < "${input_file}"
}

current_millis() {
  awk -v epoch="${EPOCHREALTIME}" 'BEGIN {
    split(epoch, parts, ".")
    printf "%d\n", (parts[1] * 1000) + substr(parts[2] "000", 1, 3)
  }'
}

elapsed_seconds_value() {
  local start_millis="$1"
  local end_millis="$2"

  awk \
    -v start_millis="${start_millis}" \
    -v end_millis="${end_millis}" \
    'BEGIN {
      elapsed_seconds = (end_millis - start_millis) / 1000
      if (elapsed_seconds < 0) {
        elapsed_seconds = 0
      }
      printf "%.2fs", elapsed_seconds
    }'
}

estimate_tokens_from_bytes() {
  local byte_count="$1"

  printf '%s\n' "$(((byte_count + 3) / 4))"
}

estimate_compactor_dollars() {
  local model="$1"
  local input_tokens="$2"
  local output_tokens="$3"
  local input_rate
  local output_rate

  case "${model}" in
    gpt-5.5)
      input_rate="125"
      output_rate="750"
      ;;
    gpt-5.4)
      input_rate="62.50"
      output_rate="375"
      ;;
    gpt-5.4-mini)
      input_rate="18.75"
      output_rate="113"
      ;;
    gpt-5.3-codex | gpt-5.3-Codex | gpt-5.2)
      input_rate="43.75"
      output_rate="350"
      ;;
    *)
      return 1
      ;;
  esac

  awk \
    -v input_tokens="${input_tokens}" \
    -v output_tokens="${output_tokens}" \
    -v input_rate="${input_rate}" \
    -v output_rate="${output_rate}" \
    'BEGIN {
      credits = ((input_tokens * input_rate) + (output_tokens * output_rate)) / 1000000
      printf "%.4f\n", credits * 0.04
    }'
}

extract_agent_usage_json() {
  local events_file="$1"

  jq -c 'select(.type == "turn.completed" and .usage) | .usage' "${events_file}" \
    | tail -n 1
}

extract_agent_thread_id() {
  local events_file="$1"

  jq -r 'select(.type == "thread.started" and .thread_id) | .thread_id' "${events_file}" \
    | tail -n 1
}

estimate_agent_cost_label() {
  local model="$1"
  local prompt_file="$2"
  local output_file="$3"
  local events_file="${4:-}"
  local input_tokens
  local output_tokens
  local estimated_dollars

  if [[ -n "${events_file}" ]] && [[ -s "${events_file}" ]]; then
    local usage_json
    usage_json="$(extract_agent_usage_json "${events_file}")" \
      || usage_json=""
    if [[ -n "${usage_json}" ]]; then
      input_tokens="$(jq -r '.input_tokens // empty' <<< "${usage_json}")"
      output_tokens="$(jq -r '.output_tokens // empty' <<< "${usage_json}")"
    fi
  fi

  if [[ -z "${input_tokens:-}" ]] || [[ -z "${output_tokens:-}" ]]; then
    input_tokens="$(estimate_tokens_from_bytes "$(count_bytes_in_file "${prompt_file}")")"
    output_tokens="$(estimate_tokens_from_bytes "$(count_bytes_in_file "${output_file}")")"
  fi

  estimated_dollars="$(estimate_compactor_dollars "${model}" "${input_tokens}" "${output_tokens}")" \
    || return 1

  printf '~$%s' "${estimated_dollars}"
}

ccusage_agent_cost_label() {
  local events_file="$1"
  local ccusage_file="$2"
  local thread_id
  local since_date
  local cost_usd

  command -v npx > /dev/null 2>&1 || return 1
  [[ -s "${events_file}" ]] || return 1

  thread_id="$(extract_agent_thread_id "${events_file}")" \
    || return 1
  [[ -n "${thread_id}" ]] || return 1

  since_date="$(date -u +%F)" \
    || return 1
  npx --yes ccusage codex session --json --offline --since "${since_date}" > "${ccusage_file}" 2> /dev/null \
    || return 1

  cost_usd="$(
    jq -r --arg thread_id "${thread_id}" \
      '.sessions[]? | select(.sessionId | contains($thread_id)) | .costUSD // empty' \
      "${ccusage_file}" \
      | tail -n 1
  )" || return 1
  [[ -n "${cost_usd}" ]] || return 1

  awk -v cost_usd="${cost_usd}" 'BEGIN { printf "$%.4f", cost_usd }'
}

agent_cost_label() {
  local model="$1"
  local prompt_file="$2"
  local output_file="$3"
  local events_file="$4"
  local ccusage_file="$5"

  ccusage_agent_cost_label "${events_file}" "${ccusage_file}" \
    || estimate_agent_cost_label "${model}" "${prompt_file}" "${output_file}" "${events_file}"
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
  local extracted_token_estimate
  local retained_token_estimate
  local trimmed_token_estimate
  local timestamp
  extracted_token_estimate="$(estimate_tokens_from_bytes "${char_count}")"
  retained_token_estimate="$(estimate_tokens_from_bytes "${retained_byte_count}")"
  trimmed_token_estimate="$(estimate_tokens_from_bytes "${trimmed_byte_count}")"
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
    --argjson extracted_token_estimate "${extracted_token_estimate}" \
    --argjson retained_token_estimate "${retained_token_estimate}" \
    --argjson trimmed_token_estimate "${trimmed_token_estimate}" \
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
        estimated_tokens: {
          extracted: $extracted_token_estimate,
          retained: $retained_token_estimate,
          saved: $trimmed_token_estimate
        },
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
  local command_file="$7"
  local cost_label="${8:-}"
  local elapsed_seconds="${9:-}"
  local trimmed_token_estimate
  trimmed_token_estimate="$(estimate_tokens_from_bytes "${trimmed_byte_count}")"
  local details="-${trimmed_byte_count}B, ~${trimmed_token_estimate} tokens, ${line_count}l"

  if [[ -n "${cost_label}" ]]; then
    details="${details}, ${cost_label}"
  fi

  if [[ -n "${elapsed_seconds}" ]]; then
    details="${details}, ${elapsed_seconds}"
  fi

  local message="Compacted ${tool_name}: ${char_count}B -> ${retained_byte_count}B (${details})"

  if [[ "${log_status}" != "logged" ]]; then
    message="${message}; state log unavailable"
  fi

  jq -n \
    --arg system_message "${message}" \
    --rawfile bash_command "${command_file}" \
    '{
      systemMessage: (
        if ($bash_command | length) > 0 then
          $system_message
          + "; command: "
          + ($bash_command | sub("\n$"; "") | gsub("\n"; "\\n"))
        else
          $system_message
        end
      )
    }'
}

run_agent_compaction() {
  local tool_name="$1"
  local char_count="$2"
  local line_count="$3"
  local command_file="$4"
  local response_text_file="$5"
  local max_chars="$6"
  local prompt_file="$7"
  local output_file="$8"
  local stdout_file="$9"
  local stderr_file="${10}"
  local bare_workspace="${11}"
  local timeout_sec="${12}"

  local model="${CODEX_TOOL_RESULT_COMPACTOR_MODEL:-${DEFAULT_COMPACTOR_MODEL}}"
  local reasoning_effort="${CODEX_TOOL_RESULT_COMPACTOR_REASONING:-${DEFAULT_COMPACTOR_REASONING_EFFORT}}"

  write_agent_prompt \
    "${tool_name}" \
    "${char_count}" \
    "${line_count}" \
    "${command_file}" \
    "${response_text_file}" \
    "${max_chars}" \
    "${prompt_file}"

  mkdir -p "${bare_workspace}"

  command -v timeout > /dev/null 2>&1 || return 1

  timeout "${timeout_sec}s" codex exec \
    --json \
    --ignore-user-config \
    --ignore-rules \
    --skip-git-repo-check \
    --color never \
    --cd "${bare_workspace}" \
    --model "${model}" \
    --config "model_reasoning_effort=\"${reasoning_effort}\"" \
    --config 'features.hooks=false' \
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
  local command_file
  local response_text_file
  local summary_file
  local prompt_file
  local agent_output_file
  local agent_stdout_file
  local agent_stderr_file
  local ccusage_output_file
  local bare_workspace
  input_file="$(make_tmp_file "input.json")"
  command_file="$(make_tmp_file "command.txt")"
  response_text_file="$(make_tmp_file "response.txt")"
  summary_file="$(make_tmp_file "summary.txt")"
  prompt_file="$(make_tmp_file "agent-prompt.txt")"
  agent_output_file="$(make_tmp_file "agent-output.txt")"
  agent_stdout_file="$(make_tmp_file "agent-stdout.txt")"
  agent_stderr_file="$(make_tmp_file "agent-stderr.txt")"
  ccusage_output_file="$(make_tmp_file "ccusage-output.json")"
  bare_workspace="$(make_tmp_file "bare-workspace")"
  TMP_FILES=(
    "${input_file}"
    "${command_file}"
    "${response_text_file}"
    "${summary_file}"
    "${prompt_file}"
    "${agent_output_file}"
    "${agent_stdout_file}"
    "${agent_stderr_file}"
    "${ccusage_output_file}"
    "${bare_workspace}"
  )
  trap 'cleanup_tmp_files' EXIT

  cat > "${input_file}"

  jq -e '.hook_event_name == "PostToolUse"' "${input_file}" > /dev/null \
    || exit 0

  references_markdown_file "${input_file}" && exit 0

  extract_tool_response_text "${input_file}" "${response_text_file}"
  extract_bash_command_text "${input_file}" "${command_file}"

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
  local compaction_started_millis
  compaction_started_millis="$(current_millis)"
  if command -v codex > /dev/null 2>&1; then
    if run_agent_compaction \
      "${tool_name}" \
      "${char_count}" \
      "${line_count}" \
      "${command_file}" \
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
        local agent_cost_label=""
        local elapsed_seconds=""
        {
          printf 'The previous %s result was compacted by a bare Codex worker.\n\n' "${tool_name}"
          if [[ -s "${command_file}" ]]; then
            printf 'Exact bash command:\n```bash\n'
            cat "${command_file}"
            printf '```\n\n'
          fi
          printf '%s\n' "${agent_summary}"
        } > "${summary_file}"
        agent_cost_label="$(agent_cost_label \
          "${CODEX_TOOL_RESULT_COMPACTOR_MODEL:-${DEFAULT_COMPACTOR_MODEL}}" \
          "${prompt_file}" \
          "${agent_output_file}" \
          "${agent_stdout_file}" \
          "${ccusage_output_file}")" \
          || agent_cost_label=""
        elapsed_seconds="$(elapsed_seconds_value "${compaction_started_millis}" "$(current_millis)")"
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
          "${log_status}" \
          "${command_file}" \
          "${agent_cost_label}" \
          "${elapsed_seconds}"
        exit 0
      fi
    fi
  fi

  local elapsed_seconds=""
  elapsed_seconds="$(elapsed_seconds_value "${compaction_started_millis}" "$(current_millis)")"
  jq -n \
    --arg system_message "Compaction skipped ${tool_name}: agent compaction unavailable (${line_count}l, ${elapsed_seconds})" \
    --rawfile bash_command "${command_file}" \
    '{
      systemMessage: (
        if ($bash_command | length) > 0 then
          $system_message
          + "; command: "
          + ($bash_command | sub("\n$"; "") | gsub("\n"; "\\n"))
        else
          $system_message
        end
      )
    }'
}

main "$@"
