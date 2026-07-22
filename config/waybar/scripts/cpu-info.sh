#!/usr/bin/env bash

set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat << EOF
Usage: ${PROG} [OPTION]
Print CPU usage and the top CPU-consuming processes for Waybar.

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

read_cpu_times() {
  local user nice system idle iowait irq softirq steal

  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  printf '%s %s\n' \
    "$((user + nice + system + idle + iowait + irq + softirq + steal))" \
    "$((idle + iowait))"
}

main() {
  local first_total first_idle second_total second_idle
  local total_delta idle_delta percentage top_procs tooltip

  case "${1:-}" in
    -h | --help)
      usage
      exit 0
      ;;
    "") ;;
    *) fatal "Unknown option: $1" 2 ;;
  esac

  read -r first_total first_idle < <(read_cpu_times)
  sleep 0.2
  read -r second_total second_idle < <(read_cpu_times)

  total_delta=$((second_total - first_total))
  idle_delta=$((second_idle - first_idle))
  if ((total_delta == 0)); then
    percentage=0
  else
    percentage=$(((100 * (total_delta - idle_delta) + total_delta / 2) / total_delta))
  fi

  top_procs=$(ps axo pid=,pcpu=,comm= --sort=-pcpu | awk '$3 != "ps" && shown < 10 {
    printf "%7s %7.1f%%  %s\n", $1, $2, $3
    shown += 1
  }')

  tooltip="CPU: ${percentage}%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    PID      CPU  Process
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${top_procs}"

  jq --compact-output --null-input \
    --arg text "CPU ${percentage}%" \
    --arg tooltip "${tooltip}" \
    --argjson percentage "${percentage}" \
    '{text: $text, tooltip: $tooltip, percentage: $percentage}'
}

main "$@"
