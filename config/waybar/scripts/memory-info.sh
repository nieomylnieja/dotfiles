#!/usr/bin/env bash

# Get memory info
read -r total used available <<< $(free -b | awk '/^Mem:/ {print $2, $3, $7}')
percentage=$((used * 100 / total))

# Convert to human readable using awk
total_gb=$(awk "BEGIN {printf \"%.1f\", $total / 1073741824}")
used_gb=$(awk "BEGIN {printf \"%.1f\", $used / 1073741824}")

# Get top 10 processes by memory usage
top_procs=$(ps axo pid,rss,comm --sort=-rss | head -11 | tail -10 | awk '{
    mem_mb = $2 / 1024;
    printf "%-6s %7.1f MB  %s\n", $1, mem_mb, $3
}')

tooltip="Memory: ${used_gb}GiB / ${total_gb}GiB (${percentage}%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PID    Memory     Process
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${top_procs}"

# Escape for JSON
tooltip=$(echo "$tooltip" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')

echo "{\"text\": \"MEM ${percentage}%\", \"tooltip\": \"${tooltip}\"}"
