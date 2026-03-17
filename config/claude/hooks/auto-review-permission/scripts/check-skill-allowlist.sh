#!/bin/bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: check-skill-allowlist.sh <TOOL_NAME> <TOOL_INPUT_JSON> <SKILL_NAME>

Check if a tool call is permitted by a skill's allowed-tools.

Workaround for Claude Code bug: skill-level allowed-tools are not enforced by the runtime.

Arguments:
  TOOL_NAME        Name of the tool being called (e.g. Bash, Read, Write)
  TOOL_INPUT_JSON  JSON object of tool inputs
  SKILL_NAME       Name of the skill to check (e.g. git-commit)

Exit codes:
  0  — tool is allowed by the skill
  1  — skill does not allow this tool call

Example:
  check-skill-allowlist.sh Bash '{"command":"git commit -m fix"}' git-commit
EOF
  exit 0
fi

TOOL_NAME="${1:-}"
TOOL_INPUT="${2:-{}}"
SKILL_NAME="${3:-}"

if [ -z "$TOOL_NAME" ] || [ -z "$SKILL_NAME" ]; then
  echo "Usage: $0 <TOOL_NAME> <TOOL_INPUT_JSON> <SKILL_NAME>" >&2
  exit 1
fi

SKILLS_DIR="${DOTFILES:-$HOME/.dotfiles}/config/agents/skills"
SKILL_FILE="$SKILLS_DIR/$SKILL_NAME/SKILL.md"

if [ ! -f "$SKILL_FILE" ]; then
  exit 1
fi

# Determine the primary argument to match against tool patterns
SKILL_MATCH_ARG=""
case "$TOOL_NAME" in
Bash) SKILL_MATCH_ARG=$(echo "$TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null) ;;
Write | Read | Edit | MultiEdit) SKILL_MATCH_ARG=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null) ;;
WebFetch) SKILL_MATCH_ARG=$(echo "$TOOL_INPUT" | jq -r '.url // empty' 2>/dev/null) ;;
esac

# Extract allowed-tools single-line value from YAML frontmatter
SKILL_ALLOWED=$(awk 'NR>1 { if (/^---$/) exit; if (/^allowed-tools:/) { sub(/^allowed-tools:[[:space:]]*/, ""); print; exit } }' "$SKILL_FILE")
[ -z "$SKILL_ALLOWED" ] && exit 1

# Parse each "ToolName" or "ToolName(pattern)" token
while IFS= read -r token; do
  [ -z "$token" ] && continue
  tok_tool="${token%%(*}"
  [ "$tok_tool" != "$TOOL_NAME" ] && continue

  if [[ "$token" == *"("* ]]; then
    tok_pat="${token#*(}"
    tok_pat="${tok_pat%)}"
    tok_pat="${tok_pat//\*\*/*}" # normalize ** -> * for bash glob matching
    # shellcheck disable=SC2053
    [[ "$SKILL_MATCH_ARG" == $tok_pat ]] || continue
  fi

  echo "skill:$SKILL_NAME token:$token" >&2
  exit 0
done < <(echo "$SKILL_ALLOWED" | grep -oE '[A-Za-z][A-Za-z0-9_]+(\([^)]*\))?')

exit 1
