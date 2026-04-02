#!/usr/bin/env bash
set -euo pipefail

# PostToolUseFailure hook: exponential backoff on transient API errors.
#
# On transient errors (529, 503, rate limits), this hook:
# 1. Tracks retry count per session via a state file
# 2. Sleeps with exponential backoff (5s, 10s, 20s, ..., capped at 120s)
# 3. Returns additionalContext instructing Claude to retry
#
# Retries indefinitely — once the delay reaches 120s it stays there.

readonly PROG="${0##*/}"
readonly BASE_DELAY=5
readonly MAX_DELAY=120
readonly STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/claude-hooks"
readonly TRANSIENT_ERROR_PATTERN='529|overload|503|service.unavailable|rate.limit|too.many.requests|capacity|temporarily'

log() { echo "${PROG}: $*" >&2; }

read_input() {
  local input
  input="$(cat)"
  echo "${input}"
}

is_transient_error() {
  local error="$1"
  echo "${error}" | grep -qiE "${TRANSIENT_ERROR_PATTERN}"
}

get_retry_count() {
  local state_file="$1"
  local count=0
  if [[ -f "${state_file}" ]]; then
    count="$(cat "${state_file}")"
  fi
  echo "${count}"
}

compute_delay() {
  local retry_count="$1"
  local delay
  delay=$((BASE_DELAY * (1 << (retry_count - 1))))
  if ((delay > MAX_DELAY)); then
    delay="${MAX_DELAY}"
  fi
  echo "${delay}"
}

emit_retry_context() {
  local tool_name="$1"
  local attempt="$2"
  jq -n \
    --arg tool "${tool_name}" \
    --arg attempt "${attempt}" \
    '{
      "hookSpecificOutput": {
        "hookEventName": "PostToolUseFailure",
        "additionalContext": ("Transient API error on " + $tool + " (attempt " + $attempt + "). Backoff complete. Retry the exact same tool call now. Do NOT skip or abandon the operation.")
      }
    }'
}

main() {
  local input
  input="$(read_input)"

  local error
  error="$(echo "${input}" | jq -r '.error // empty')"

  if ! is_transient_error "${error}"; then
    exit 0
  fi

  local session_id
  session_id="$(echo "${input}" | jq -r '.session_id // "unknown"')"

  local tool_name
  tool_name="$(echo "${input}" | jq -r '.tool_name // "unknown"')"

  mkdir -p "${STATE_DIR}"
  local state_file="${STATE_DIR}/retry-${session_id}"

  local retry_count
  retry_count="$(get_retry_count "${state_file}")"
  retry_count=$((retry_count + 1))
  echo "${retry_count}" > "${state_file}"

  local delay
  delay="$(compute_delay "${retry_count}")"

  log "transient API error (attempt ${retry_count}), backing off ${delay}s..."
  sleep "${delay}"

  emit_retry_context "${tool_name}" "${retry_count}"
}

main "$@"
