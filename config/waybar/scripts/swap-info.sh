#!/usr/bin/env bash

set -euo pipefail

readonly PROG="${0##*/}"

usage() {
  cat << EOF
Usage: ${PROG} [OPTION]
Print swap usage, swap devices, and top swap-consuming processes for Waybar.

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
  local total used percentage total_gb used_gb devices top_procs tooltip

  case "${1:-}" in
    -h | --help)
      usage
      exit 0
      ;;
    "") ;;
    *) fatal "Unknown option: $1" 2 ;;
  esac

  read -r total used < <(free -b | awk '/^Swap:/ {print $2, $3}')
  if ((total == 0)); then
    percentage=0
  else
    percentage=$((used * 100 / total))
  fi

  total_gb=$(awk -v bytes="${total}" 'BEGIN {printf "%.1f", bytes / 1073741824}')
  used_gb=$(awk -v bytes="${used}" 'BEGIN {printf "%.1f", bytes / 1073741824}')

  devices=$(awk 'NR > 1 {
    printf "%9.1f / %5.1f GiB  %s\n", $4 / 1048576, $3 / 1048576, $1
  }' /proc/swaps)

  top_procs=$(ps -eo pid= | awk '
    {
      status = "/proc/" $1 "/status"
      name = ""
      swap = 0

      while ((getline line < status) > 0) {
        if (line ~ /^Name:/) {
          sub(/^Name:[[:space:]]*/, "", line)
          name = line
        } else if (line ~ /^VmSwap:/) {
          split(line, fields, /[[:space:]]+/)
          swap = fields[2]
        }
      }
      close(status)

      if (name != "" && swap > 0) {
        swaps[name] += swap
        counts[name] += 1
      }
    }

    END {
      for (name in swaps) {
        printf "%d\t%d\t%s\n", swaps[name], counts[name], name
      }
    }
  ' | sort -nr | awk -F '\t' 'shown < 10 {
    printf "%9.1f MB  %5d  %s\n", $1 / 1024, $2, $3
    shown += 1
  }')

  tooltip="Swap: ${used_gb}GiB / ${total_gb}GiB (${percentage}%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     Used /     Size  Device
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${devices}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     Swap  Procs  Process
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${top_procs}"

  jq --compact-output --null-input \
    --arg text "SWAP ${percentage}%" \
    --arg tooltip "${tooltip}" \
    --argjson percentage "${percentage}" \
    '{text: $text, tooltip: $tooltip, percentage: $percentage}'
}

main "$@"
