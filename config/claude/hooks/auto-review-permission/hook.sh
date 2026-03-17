#!/bin/bash
set -euo pipefail

# --- Recursion guard ---
# Prevents infinite loops if the AI subprocess triggers a PermissionRequest
if [ "${AUTO_REVIEW_ACTIVE:-}" = "1" ]; then
  exit 0
fi
export AUTO_REVIEW_ACTIVE=1

AI_MODEL="claude-opus-4-6"
AI_TIMEOUT=30
BASE_DIR="$HOME/.claude/hooks/auto-review-permission"
LOG_FILE="$BASE_DIR/log.json"
PID_FILE="$BASE_DIR/review.pid"
PAUSE_FILE="$BASE_DIR/review.pause"
DEBUG_FILE="$BASE_DIR/review.debug"
SETTINGS_FILE="$HOME/.claude/settings.json"

# --- Load settings.json allow/deny patterns for AI context ---
SETTINGS_ALLOW=""
SETTINGS_DENY=""
if [ -f "$SETTINGS_FILE" ]; then
  SETTINGS_ALLOW=$(jq -r '.permissions.allow // [] | .[]' "$SETTINGS_FILE" 2>/dev/null || true)
  SETTINGS_DENY=$(jq -r '.permissions.deny // [] | .[]' "$SETTINGS_FILE" 2>/dev/null || true)
fi

# --- Read stdin ---
HOOK_INPUT=$(cat)
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$HOOK_INPUT" | jq -c '.tool_input // {}')
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty')

# Malformed input -> passthrough
if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

GIT_BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || true)

log_json() {
  local event="$1" reason="${2:-}" input="${3:-}"
  jq -nc \
    --arg ts "$(date -Iseconds)" \
    --arg event "$event" \
    --arg tool "${TOOL_NAME:-}" \
    --arg cwd "${CWD:-}" \
    --arg branch "${GIT_BRANCH:-}" \
    --arg reason "$reason" \
    --arg input "$input" \
    'if $input != "" then {ts:$ts,event:$event,tool:$tool,cwd:$cwd,branch:$branch,reason:$reason,input:$input} else {ts:$ts,event:$event,tool:$tool,cwd:$cwd,branch:$branch,reason:$reason} end
    | if .branch == "" then del(.branch) else . end' >>"$LOG_FILE"
}

allow() {
  local reason="${1:-}" input="${2:-}"
  log_json "approve" "$reason" "$input"
  echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
  exit 0
}

deny() {
  local reason="${1:-}" input="${2:-}"
  log_json "deny" "$reason" "$input"
  jq -n --arg reason "$reason" \
    '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":$reason}}}'
  exit 0
}

ask() {
  local reason="${1:-}" input="${2:-}"
  log_json "ask" "$reason" "$input"
  local location="$CWD"
  [ -n "$GIT_BRANCH" ] && location="$CWD ($GIT_BRANCH)"
  notify-send -u normal "Claude permission request" "$TOOL_NAME requires your approval\n$location" 2>/dev/null || true
  exit 0
}

# --- Debug mode: log every invocation with full body ---
if [ -f "$DEBUG_FILE" ]; then
  jq -nc --arg ts "$(date -Iseconds)" --argjson body "$HOOK_INPUT" \
    '{ts:$ts,event:"incoming",body:$body}' >>"$LOG_FILE"
fi

# --- Pause mode: skip AI review, fall through to manual approval ---
# Touch ~/.claude/hooks/auto-review.pause to go fully manual
# Remove the file to re-enable AI auto-review
if [ -f "$PAUSE_FILE" ]; then
  log_json "paused" "auto-review paused, manual approval"
  exit 0
fi

# ============================================================================
# ALLOWLIST: only these tool types may be AI-auto-reviewed.
# Everything NOT listed here falls through to manual approval (human decides).
#
# This ensures AI auto-review NEVER bypasses human-in-the-loop for:
#   - AskUserQuestion    (questions directed at user)
#   - ExitPlanMode       (plan approval — user must review)
#   - EnterPlanMode      (mode change — user must consent)
#   - EnterWorktree      (environment change — user must consent)
#   - Skill              (skill invocation)
#   - TaskCreate/Update/List/Get/Stop  (task management)
#   - Notification       (user notifications)
#   - Any future unknown tool types
# ============================================================================
REVIEWABLE_TOOLS='^(Bash|Edit|Write|MultiEdit|NotebookEdit|WebFetch|WebSearch|Glob|Grep|Read|Task)$'
IS_MCP=false

if echo "$TOOL_NAME" | grep -qE '^mcp__'; then
  IS_MCP=true
elif ! echo "$TOOL_NAME" | grep -qE "$REVIEWABLE_TOOLS"; then
  log_json "manual" "not auto-reviewable, human decides"
  exit 0
fi

# --- Auto-approve chrome-devtools operations on dev environments ---
if echo "$TOOL_NAME" | grep -qE '^mcp__chrome-devtools__'; then
  # For navigation tools, check the URL matches dev-*.nobl9.dev
  if echo "$TOOL_NAME" | grep -qE '(navigate_page|new_page)$'; then
    TARGET_URL=$(echo "$TOOL_INPUT" | jq -r '.url // empty' 2>/dev/null)
    if echo "$TARGET_URL" | grep -qE '^https?://dev-[^.]+\.nobl9\.dev'; then
      allow "chrome-devtools nav to dev env ($TARGET_URL)"
    else
      ask "chrome-devtools nav to non-dev URL ($TARGET_URL)"
    fi
  fi
  # All other chrome-devtools operations (click, fill, snapshot, etc.) — auto-approve
  allow "chrome-devtools operation on current page"
fi

# --- MCP write operations on external services -> always ask user ---
if [ "$IS_MCP" = true ]; then
  MCP_ACTION=$(echo "$TOOL_NAME" | grep -oE '[^_]+$' || true)
  if echo "$MCP_ACTION" | grep -qiE '^(create|update|delete|add|write|push|merge|assign|move|duplicate|remove|post|send|close)'; then
    ask "MCP write operation, requiring manual approval"
  fi
fi

# --- Check skill allowlists before invoking AI ---
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)/scripts"
SKILLS_DIR="${DOTFILES:-$HOME/.dotfiles}/config/agents/skills"
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  if "$SCRIPTS_DIR/check-skill-allowed-tools.sh" "$TOOL_NAME" "$TOOL_INPUT" "$skill_name" 2>/dev/null; then
    allow "allowed by skill allowlist ($skill_name)"
  fi
done

# --- Truncate large tool input (keep first 4000 chars) ---
TRUNCATED_INPUT=$(echo "$TOOL_INPUT" | head -c 4000)

# --- Build AI review prompt ---
# Inject settings.json context so the AI reviewer is an informed extension of the user's policy
SETTINGS_CONTEXT=""
if [ -n "$SETTINGS_ALLOW" ] || [ -n "$SETTINGS_DENY" ]; then
  SETTINGS_CONTEXT="
SETTINGS CONTEXT (from the user's settings.json permission policy):
The user's settings.json defines explicit allow and deny patterns. Claude Code enforces these
before the hook runs: denied patterns are hard-blocked, allowed patterns are auto-approved.
This hook only sees the gray zone — commands that didn't match either list exactly.
Use these lists to understand the user's trust baseline and security boundaries."

  if [ -n "$SETTINGS_ALLOW" ]; then
    SETTINGS_CONTEXT="${SETTINGS_CONTEXT}

ALLOWED patterns (user trusts these — if a command is similar but didn't match exactly, lean toward approve):
${SETTINGS_ALLOW}"
  fi

  if [ -n "$SETTINGS_DENY" ]; then
    SETTINGS_CONTEXT="${SETTINGS_CONTEXT}

DENIED patterns (user considers these off-limits — if a command is similar to these, lean toward deny or ask):
${SETTINGS_DENY}"
  fi
fi

AI_PROMPT="You are a security reviewer for an AI coding assistant. Review this tool call and decide: approve, ask, or deny.
TOOL: ${TOOL_NAME}
CWD: ${CWD}
INPUT: ${TRUNCATED_INPUT}
${SETTINGS_CONTEXT}
APPROVE if:
- Standard dev commands (npm test/install/build, git operations, make, cargo, etc.)
- Reading/writing/editing files within the project directory
- Running linters, formatters, type checkers, test suites
- Standard CLI tools used non-destructively
- curl/wget GET requests to known/public URLs
- General purpose commands that don't touch credentials or sensitive data
- Commands similar to the ALLOWED patterns above (same tool, similar arguments)
DENY (hard block, no override) ONLY for truly dangerous operations:
- Commands matching or similar to the DENIED patterns above
- Accessing or exfiltrating credentials/secrets (~/.ssh, ~/.aws, ~/.env, tokens, API keys)
- Piping secrets or credentials to external services
- Mass/recursive deletion outside safe targets (node_modules, dist, build, .cache)
- Obfuscated commands designed to hide intent (base64 decode | bash, eval of encoded strings)
- curl | bash patterns (downloading and executing remote scripts)
ASK (let the user decide) for anything uncertain:
- Commands you're not fully sure about
- curl/wget POST requests
- sudo or privilege escalation
- Force pushing to remote repos
- Destructive database operations
- Anything not clearly safe but not clearly credential/leak/mass-deletion risk
When in doubt, ask -- NOT deny.
Respond with ONLY a JSON object: {\"decision\":\"approve\" or \"ask\" or \"deny\", \"reasoning\":\"brief explanation\"}"

# --- Call AI reviewer with timeout and progress ---
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE" "$PID_FILE"' EXIT

log_json "reviewing" "AI review started"
echo "⏳ auto-review: $TOOL_NAME ..." >&2

claude -p \
  --output-format json \
  --model "$AI_MODEL" \
  --tools "" \
  --no-session-persistence \
  "$AI_PROMPT" >"$TMPFILE" 2>/dev/null &
CLAUDE_PID=$!

# Write PID so user can: kill $(cat ~/.claude/hooks/auto-review.pid)
echo "$CLAUDE_PID" >"$PID_FILE"

# Timeout killer
(sleep "$AI_TIMEOUT" && kill "$CLAUDE_PID" 2>/dev/null) &
TIMER_PID=$!

# Progress ticks at 10s and 20s
(
  sleep 10
  if kill -0 "$CLAUDE_PID" 2>/dev/null; then
    log_json "reviewing" "10s elapsed"
  fi
  sleep 10
  if kill -0 "$CLAUDE_PID" 2>/dev/null; then
    log_json "reviewing" "20s elapsed"
  fi
) &
PROGRESS_PID=$!

if wait "$CLAUDE_PID" 2>/dev/null; then
  kill "$TIMER_PID" 2>/dev/null
  kill "$PROGRESS_PID" 2>/dev/null
  wait "$TIMER_PID" 2>/dev/null || true
  wait "$PROGRESS_PID" 2>/dev/null || true
  AI_OUTPUT=$(cat "$TMPFILE")
else
  kill "$TIMER_PID" 2>/dev/null
  kill "$PROGRESS_PID" 2>/dev/null
  wait "$TIMER_PID" 2>/dev/null || true
  wait "$PROGRESS_PID" 2>/dev/null || true
  echo "⚠️  auto-review: timed out → manual approval" >&2
  ask "AI review failed/timed out/killed, manual approval"
fi

# --- Parse response ---
RESULT_TEXT=$(echo "$AI_OUTPUT" | jq -r '.result // empty' 2>/dev/null)
if [ -z "$RESULT_TEXT" ]; then
  RESULT_TEXT="$AI_OUTPUT"
fi

# Try direct jq parse, then strip markdown fences as fallback
CLEAN_JSON="$RESULT_TEXT"
if ! echo "$CLEAN_JSON" | jq -e '.decision' >/dev/null 2>&1; then
  CLEAN_JSON=$(echo "$RESULT_TEXT" | sed '/^```/d')
fi

DECISION=$(echo "$CLEAN_JSON" | jq -r '.decision // empty' 2>/dev/null)
REASONING=$(echo "$CLEAN_JSON" | jq -r '.reasoning // "No reasoning provided"' 2>/dev/null)

LOG_INPUT=$(echo "$TRUNCATED_INPUT" | head -c 500)

# --- Emit hook decision ---
if [ "$DECISION" = "approve" ]; then
  echo "✅ auto-review: approved — $REASONING" >&2
  allow "$REASONING" "$LOG_INPUT"
elif [ "$DECISION" = "deny" ]; then
  echo "❌ auto-review: denied — $REASONING" >&2
  deny "$REASONING" "$LOG_INPUT"
else
  # "ask" or unrecognized -> fall through to manual approval
  echo "🤔 auto-review: uncertain → manual approval" >&2
  ask "$REASONING" "$LOG_INPUT"
fi
