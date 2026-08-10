#!/usr/bin/env bash

set -euo pipefail

readonly PROG="${0##*/}"
readonly PROC_ROOT="${TMUX_CODEX_PROC_ROOT:-/proc}"

SELF_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF_PATH

usage() {
  cat << EOF
Usage: ${PROG} [OPTION]
Inspect Codex sessions running in tmux panes and switch to the selected pane.

Options:
      --list                print running Codex sessions as tab-separated rows
      --preview TRANSCRIPT  print details from a Codex transcript
  -h, --help                display this help and exit

The interactive picker requires an attached tmux client. Enter switches to the
selected Codex pane; Esc or Ctrl-C cancels without changing panes.

Exit status:
  0  success or picker cancelled
  1  operational error
  2  usage error
EOF
}

fatal() {
  echo "${PROG}: ERROR: $1" >&2
  exit "${2:-1}"
}

require_command() {
  local command_name="$1"
  command -v "${command_name}" > /dev/null 2>&1 \
    || fatal "required command not found: ${command_name}"
}

single_line() {
  local value="$1"
  value="${value//$'\t'/ }"
  value="${value//$'\n'/ }"
  printf '%s' "${value}"
}

shorten_home() {
  local path="$1"

  if [[ "${path}" == "${HOME}" ]]; then
    printf '~'
  elif [[ "${path}" == "${HOME}/"* ]]; then
    printf '%s/%s' '~' "${path#"${HOME}/"}"
  else
    printf '%s' "${path}"
  fi
}

descendant_pids() {
  local root_pid="$1"
  local pid
  local child
  local children_file
  local -a children=()
  local -a queue=("${root_pid}")

  while ((${#queue[@]} > 0)); do
    pid="${queue[0]}"
    queue=("${queue[@]:1}")
    printf '%s\n' "${pid}"

    children_file="${PROC_ROOT}/${pid}/task/${pid}/children"
    [[ -r "${children_file}" ]] || continue

    children=()
    IFS=' ' read -r -a children < "${children_file}" || true
    for child in "${children[@]}"; do
      [[ "${child}" =~ ^[0-9]+$ ]] || continue
      queue+=("${child}")
    done
  done
}

find_codex_pid() {
  local pane_pid="$1"
  local pid
  local process_name

  while IFS= read -r pid; do
    [[ -r "${PROC_ROOT}/${pid}/comm" ]] || continue
    IFS= read -r process_name < "${PROC_ROOT}/${pid}/comm" || continue
    if [[ "${process_name}" == "codex" ]]; then
      printf '%s\n' "${pid}"
      return 0
    fi
  done < <(descendant_pids "${pane_pid}")

  return 1
}

find_primary_transcript() {
  local codex_pid="$1"
  local fd_path
  local first_record
  local is_primary
  local transcript
  local -a fd_paths=()

  shopt -s nullglob
  fd_paths=("${PROC_ROOT}/${codex_pid}/fd/"*)
  shopt -u nullglob

  for fd_path in "${fd_paths[@]}"; do
    transcript="$(readlink "${fd_path}" 2> /dev/null)" || continue
    [[ "${transcript}" == *.jsonl ]] || continue
    [[ -r "${transcript}" ]] || continue
    IFS= read -r first_record < "${transcript}" || continue

    is_primary="$(
      jq -r '
        .type == "session_meta"
          and .payload.originator == "codex-tui"
          and .payload.source == "cli"
      ' <<< "${first_record}" 2> /dev/null
    )" || continue

    if [[ "${is_primary}" == "true" ]]; then
      printf '%s\n' "${transcript}"
      return 0
    fi
  done

  return 1
}

read_session_id() {
  local transcript="$1"
  local first_record

  IFS= read -r first_record < "${transcript}" || return 1
  jq -r '.payload.id // .payload.session_id // empty' <<< "${first_record}"
}

session_state() {
  local transcript="$1"
  local last_state

  last_state="$(
    rg -o '"type":"(task_started|task_complete|turn_aborted)"' "${transcript}" 2> /dev/null \
      | tail -n 1
  )" || true

  case "${last_state}" in
    '"type":"task_started"')
      printf 'busy'
      ;;
    '"type":"task_complete"' | '"type":"turn_aborted"')
      printf 'idle'
      ;;
    *)
      printf 'starting'
      ;;
  esac
}

list_sessions() {
  local session_name
  local window_index
  local pane_index
  local pane_id
  local pane_pid
  local pane_path
  local pane_title
  local codex_pid
  local transcript
  local session_id
  local state
  local display_path
  local display_title
  local pane_separator=$'\x1f'
  local pane_rows

  pane_rows="$(
    tmux list-panes -a \
      -F "#{session_name}${pane_separator}#{window_index}${pane_separator}#{pane_index}${pane_separator}#{pane_id}${pane_separator}#{pane_pid}${pane_separator}#{pane_current_path}${pane_separator}#{pane_title}"
  )" || return 1

  while IFS="${pane_separator}" read -r session_name window_index pane_index pane_id pane_pid pane_path pane_title; do
    codex_pid="$(find_codex_pid "${pane_pid}")" || continue

    if transcript="$(find_primary_transcript "${codex_pid}")"; then
      session_id="$(read_session_id "${transcript}")"
      state="$(session_state "${transcript}")"
    else
      transcript="-"
      session_id="-"
      state="picker"
    fi

    display_path="$(shorten_home "${pane_path}")"
    display_title="${pane_path%/}"
    display_title="${display_title##*/}"
    display_title="$(single_line "${display_title:-${pane_title:-codex}}")"

    printf '%s\t%s.%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${session_name}" \
      "${window_index}" \
      "${pane_index}" \
      "${pane_id}" \
      "${state}" \
      "${display_path}" \
      "${session_id}" \
      "${transcript}" \
      "${codex_pid}" \
      "${display_title}"
  done <<< "${pane_rows}"
}

json_message() {
  local record="$1"

  if [[ -z "${record}" ]]; then
    return 0
  fi

  jq -r '
    (.payload.message // "")
    | gsub("[[:space:]]+"; " ")
    | if length > 500 then .[:497] + "..." else . end
  ' <<< "${record}" 2> /dev/null || true
}

preview_session() {
  local transcript="$1"
  local first_record
  local context_record
  local first_user_record
  local latest_user_record
  local latest_agent_record
  local first_prompt
  local latest_user
  local latest_agent
  local model="-"
  local -a metadata=()

  if [[ "${transcript}" == "-" || ! -r "${transcript}" ]]; then
    printf 'Codex is running, but no primary session transcript is open.\n'
    printf 'The pane may still be on the resume picker or initializing.\n'
    return 0
  fi

  IFS= read -r first_record < "${transcript}" \
    || fatal "cannot read transcript: ${transcript}"

  mapfile -t metadata < <(
    jq -r '
      [
        (.payload.cwd // "-"),
        (.payload.git.branch // "-"),
        (.payload.git.repository_url // "-")
      ]
      | .[]
    ' <<< "${first_record}"
  )

  context_record="$(
    rg '"type":"turn_context"' "${transcript}" 2> /dev/null \
      | tail -n 1
  )" || true
  if [[ -n "${context_record}" ]]; then
    model="$(jq -r '.payload.model // "-"' <<< "${context_record}" 2> /dev/null)"
  fi

  first_user_record="$(
    rg -m 1 '"type":"event_msg".*"type":"user_message"' "${transcript}" 2> /dev/null
  )" || true
  latest_user_record="$(
    rg '"type":"event_msg".*"type":"user_message"' "${transcript}" 2> /dev/null \
      | tail -n 1
  )" || true
  latest_agent_record="$(
    rg '"type":"event_msg".*"type":"agent_message"' "${transcript}" 2> /dev/null \
      | tail -n 1
  )" || true

  first_prompt="$(json_message "${first_user_record}")"
  latest_user="$(json_message "${latest_user_record}")"
  latest_agent="$(json_message "${latest_agent_record}")"

  printf 'Codex session\n'
  printf '  %-12s %s\n' 'Repository' "${metadata[2]:--}"
  printf '  %-12s %s\n' 'Worktree' "${metadata[0]:--}"
  printf '  %-12s %s\n' 'Branch' "${metadata[1]:--}"
  printf '  %-12s %s\n' 'Model' "${model}"
  printf '\nConversation\n'
  printf '  %-16s %s\n' 'First prompt' "${first_prompt:--}"
  printf '  %-16s %s\n' 'Latest user' "${latest_user:--}"
  printf '  %-16s %s\n' 'Latest agent' "${latest_agent:--}"
}

switch_to_pane() {
  local session_name="$1"
  local window_index="$2"
  local pane_id="$3"

  tmux switch-client -t "=${session_name}"
  tmux select-window -t "${session_name}:${window_index}"
  tmux select-pane -t "${pane_id}"
}

run_picker() {
  local selected
  local fzf_status
  local preview_command
  local session_name
  local window_pane
  local pane_id
  local state
  local display_path
  local session_id
  local transcript
  local codex_pid
  local pane_title
  local window_index
  local session_rows
  local terminal_columns
  local preview_window
  local -a rows=()

  [[ -n "${TMUX:-}" ]] \
    || fatal "interactive mode must run inside an attached tmux client"

  session_rows="$(list_sessions)" || return 1
  [[ -n "${session_rows}" ]] || fatal "no running Codex sessions found in tmux"
  mapfile -t rows <<< "${session_rows}"

  printf -v preview_command '%q --preview {7}' "${SELF_PATH}"

  terminal_columns="$(tput cols 2> /dev/null)" || terminal_columns=80
  if [[ ! "${terminal_columns}" =~ ^[0-9]+$ ]]; then
    terminal_columns=80
  fi

  if ((terminal_columns >= 120)); then
    preview_window='right,50%,wrap'
  else
    preview_window='down,45%,wrap'
  fi

  set +e
  selected="$(
    printf '%s\n' "${rows[@]}" \
      | fzf \
        --delimiter=$'\t' \
        --with-nth='9' \
        --prompt='Codex> ' \
        --info=inline-right \
        --layout=reverse \
        --border \
        --border-label=' Ctrl-V: preview  Enter: switch ' \
        --border-label-pos=2 \
        --bind='ctrl-v:toggle-preview' \
        --preview="${preview_command}" \
        --preview-window="${preview_window}"
  )"
  fzf_status=$?
  set -e

  if [[ ${fzf_status} -eq 1 || ${fzf_status} -eq 130 ]]; then
    return 0
  fi
  [[ ${fzf_status} -eq 0 ]] || return "${fzf_status}"
  [[ -n "${selected}" ]] || return 0

  IFS=$'\t' read -r \
    session_name \
    window_pane \
    pane_id \
    state \
    display_path \
    session_id \
    transcript \
    codex_pid \
    pane_title <<< "${selected}"

  window_index="${window_pane%%.*}"
  switch_to_pane "${session_name}" "${window_index}" "${pane_id}"
}

main() {
  require_command jq
  require_command rg

  case "${1:-}" in
    "")
      require_command fzf
      require_command tmux
      run_picker
      ;;
    --list)
      [[ $# -eq 1 ]] || fatal "--list does not accept arguments" 2
      require_command tmux
      list_sessions
      ;;
    --preview)
      [[ $# -eq 2 ]] || fatal "--preview requires one transcript path" 2
      preview_session "$2"
      ;;
    -h | --help)
      [[ $# -eq 1 ]] || fatal "--help does not accept arguments" 2
      usage
      ;;
    *)
      fatal "unknown option: $1" 2
      ;;
  esac
}

main "$@"
