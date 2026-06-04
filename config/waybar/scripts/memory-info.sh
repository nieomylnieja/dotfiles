#!/usr/bin/env bash

set -euo pipefail

read -r total used _available < <(free -b | awk '/^Mem:/ {print $2, $3, $7}')
percentage=$((used * 100 / total))

total_gb=$(awk "BEGIN {printf \"%.1f\", ${total} / 1073741824}")
used_gb=$(awk "BEGIN {printf \"%.1f\", ${used} / 1073741824}")

top_procs=$(ps axo pid,rss,comm --sort=-rss --no-headers | head -10 | awk '{
    mem_mb = $2 / 1024;
    printf "%-6s %7.1f MB  %s\n", $1, mem_mb, $3
}')

tooltip="Memory: ${used_gb}GiB / ${total_gb}GiB (${percentage}%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PID    Memory     Process
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${top_procs}"

escaped_tooltip=$(printf '%s' "${tooltip}" | awk '
  BEGIN { ORS = "" }
  {
    gsub(/\\/, "\\\\")
    gsub(/"/, "\\\"")
    if (NR > 1) {
      printf "\\n"
    }
    printf "%s", $0
  }
')

printf '{"text":"MEM %s%%","tooltip":"%s","percentage":%s}\n' \
  "${percentage}" \
  "${escaped_tooltip}" \
  "${percentage}"
