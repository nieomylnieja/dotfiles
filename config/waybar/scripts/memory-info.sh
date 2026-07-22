#!/usr/bin/env bash

set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat << EOF
Usage: ${PROG} [OPTION]
Print memory usage and the top memory-consuming processes for Waybar.

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

main() {
  local total used percentage total_gb used_gb top_procs tooltip

  case "${1:-}" in
    -h | --help)
      usage
      exit 0
      ;;
    "") ;;
    *) fatal "Unknown option: $1" 2 ;;
  esac

  read -r total used < <(free -b | awk '/^Mem:/ {print $2, $3}')
  percentage=$((used * 100 / total))

  total_gb=$(awk -v bytes="${total}" 'BEGIN {printf "%.1f", bytes / 1073741824}')
  used_gb=$(awk -v bytes="${used}" 'BEGIN {printf "%.1f", bytes / 1073741824}')

  top_procs=$(ps axo pid=,rss=,comm= --sort=-rss | awk '$3 != "ps" && shown < 10 {
    printf "%7s %9.1f MB  %s\n", $1, $2 / 1024, $3
    shown += 1
  }')

  tooltip="Memory: ${used_gb}GiB / ${total_gb}GiB (${percentage}%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    PID       Memory  Process
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${top_procs}"

  jq --compact-output --null-input \
    --arg text "MEM ${percentage}%" \
    --arg tooltip "${tooltip}" \
    --argjson percentage "${percentage}" \
    '{text: $text, tooltip: $tooltip, percentage: $percentage}'
}

main "$@"
