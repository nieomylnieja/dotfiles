#!/usr/bin/env bash
# PreToolUse hook: block reading files matching patterns in block-read-patterns.txt
#
# Configure patterns in: $(dirname $0)/block-read-patterns.txt
# Each line is a glob pattern matched against the basename of the file being read.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PATTERNS_FILE="$SCRIPT_DIR/block-read-patterns.txt"

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[[ -z "$file_path" || ! -f "$PATTERNS_FILE" ]] && exit 0

basename=$(basename "$file_path")

while IFS= read -r pattern || [[ -n "$pattern" ]]; do
  # Skip empty lines and comments
  [[ -z "$pattern" || "$pattern" == \#* ]] && continue
  # shellcheck disable=SC2254
  case "$basename" in
    $pattern)
      echo "Blocked: reading '$file_path' is not allowed (matches pattern: $pattern)" >&2
      exit 2
      ;;
  esac
done < "$PATTERNS_FILE"
