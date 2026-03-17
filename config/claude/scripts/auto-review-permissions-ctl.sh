#!/bin/bash
# Control the AI auto-review hook
# Usage: auto-review-permissions.sh [kill|pause|resume|status|log|follow]

set -euo pipefail

BASE_DIR="$HOME/.claude/hooks/auto-review-permission"
PID_FILE="$BASE_DIR/review.pid"
PAUSE_FILE="$BASE_DIR/review.pause"
DEBUG_FILE="$BASE_DIR/review.debug"
LOG_FILE="$BASE_DIR/log.json"

CMD="${1:-status}"

case "$CMD" in
kill | k)
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    kill "$(cat "$PID_FILE")"
    echo "Killed AI review (PID $(cat "$PID_FILE")), falling back to manual"
  else
    echo "No active AI review"
  fi
  ;;
pause | p)
  touch "$PAUSE_FILE"
  echo "AI auto-review paused — all permissions go to manual"
  ;;
resume | r)
  rm -f "$PAUSE_FILE"
  echo "AI auto-review resumed"
  ;;
debug | d)
  touch "$DEBUG_FILE"
  echo "Debug mode enabled — all incoming hook invocations will be logged"
  ;;
nodebug | nd)
  rm -f "$DEBUG_FILE"
  echo "Debug mode disabled"
  ;;
status | s)
  if [ -f "$PAUSE_FILE" ]; then
    echo "Mode:   PAUSED (manual approval for everything)"
  else
    echo "Mode:   ACTIVE (AI auto-review enabled)"
  fi
  if [ -f "$DEBUG_FILE" ]; then
    echo "Debug:  ON (all invocations logged)"
  else
    echo "Debug:  off"
  fi
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Review: IN PROGRESS (PID $(cat "$PID_FILE"))"
  else
    echo "Review: idle"
  fi
  ;;
log | l)
  if [ -f "$LOG_FILE" ]; then
    tail -20 "$LOG_FILE" | while IFS= read -r line; do
      echo "$line" | jq -r '"[\(.ts)] \(.event | ascii_upcase)  \(.tool)" + (if .input then "\n  input: \(.input[:120])" else "" end) + (if .reason != "" then "\n  why:   \(.reason)" else "" end) + "\n"'
    done
  else
    echo "No log file yet"
  fi
  ;;
follow | f)
  tail -f "$LOG_FILE" | while IFS= read -r line; do
    echo "$line" | jq -r '"[\(.ts)] \(.event | ascii_upcase)  \(.tool)" + (if .input then "\n  input: \(.input[:120])" else "" end) + (if .reason != "" then "\n  why:   \(.reason)" else "" end) + "\n"'
  done
  ;;
*)
  echo "Usage: $(basename "$0") [kill|pause|resume|debug|nodebug|status|log|follow]"
  echo "  kill    (k)   Kill current AI review, fall back to manual"
  echo "  pause   (p)   Pause all AI auto-review"
  echo "  resume  (r)   Re-enable AI auto-review"
  echo "  debug   (d)   Enable debug mode (log all incoming invocations)"
  echo "  nodebug (nd)  Disable debug mode"
  echo "  status  (s)   Show current state"
  echo "  log     (l)   Show last 20 log entries"
  echo "  follow  (f)   Tail the log (live)"
  ;;
esac
