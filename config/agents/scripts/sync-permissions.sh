#!/usr/bin/env bash

set -euo pipefail

readonly PROG="${0##*/}"

log() {
	printf '%s\n' "${PROG}: $*" >&2
}

warn() {
	printf '%s\n' "${PROG}: WARNING: $*" >&2
}

fatal() {
	printf '%s\n' "${PROG}: ERROR: $*" >&2
	exit "${2:-1}"
}

usage() {
	cat <<'EOF'
Usage: sync-permissions.sh [OPTIONS]

Sync shared permissions from config/agents/permissions.json into:
- config/claude/settings.json
- config/opencode/opencode.json
- config/agents/skills/*/SKILL.md allowed-tools frontmatter

Options:
  --source PATH   permissions source file (default: config/agents/permissions.json)
  --dry-run       print what would change, do not write files
  -h, --help      display this help and exit

Exit status:
  0  success
  1  general error
  2  usage error
EOF
}

tool_to_claude() {
	local key="$1"

	case "${key}" in
	read) printf '%s' "Read" ;;
	edit) printf '%s' "Edit|Write" ;;
	glob) printf '%s' "Glob" ;;
	grep) printf '%s' "Grep" ;;
	bash) printf '%s' "Bash" ;;
	task) printf '%s' "Agent" ;;
	todowrite) printf '%s' "TodoWrite" ;;
	question) printf '%s' "AskUserQuestion" ;;
	webfetch) printf '%s' "WebFetch" ;;
	websearch) printf '%s' "WebSearch" ;;
	skill) printf '%s' "Skill" ;;
	lsp) printf '%s' "LSP" ;;
	codesearch)
		warn "codesearch does not map cleanly to Claude permissions; skipping"
		return 1
		;;
	list)
		warn "list has no Claude permission equivalent; skipping"
		return 1
		;;
	external_directory)
		warn "external_directory has no Claude permission equivalent; skipping"
		return 1
		;;
	doom_loop)
		warn "doom_loop has no Claude permission equivalent; skipping"
		return 1
		;;
	'*')
		warn "global '*' rule has no direct Claude equivalent; skipping"
		return 1
		;;
	*)
		warn "unmapped permission key '${key}'; skipping"
		return 1
		;;
	esac

	return 0
}

append_rule_once() {
	local file_path="$1"
	local rule="$2"

	if [[ -z "${rule}" ]]; then
		return 0
	fi

	if [[ -f "${file_path}" ]]; then
		if rg --fixed-strings --line-regexp --quiet -- "${rule}" "${file_path}"; then
			return 0
		fi
	fi

	printf '%s\n' "${rule}" >>"${file_path}"
}

emit_claude_rule() {
	local key="$1"
	local pattern="$2"
	local action="$3"
	local target_file="$4"
	local scope="$5"

	local mapped
	if ! mapped="$(tool_to_claude "${key}")"; then
		return 0
	fi

	if [[ "${action}" != "allow" ]] && [[ "${action}" != "ask" ]] && [[ "${action}" != "deny" ]]; then
		warn "invalid action '${action}' in ${scope}.${key}; expected allow|ask|deny"
		return 0
	fi

	local spec="${pattern}"
	local rule=""

	if [[ "${mapped}" == mcp__* ]]; then
		if [[ "${spec}" != "*" ]]; then
			warn "pattern-level rules for '${key}' are not supported in Claude; skipping ${scope}.${key}.${spec}"
			return 0
		fi
		rule="${mapped}"
	elif [[ "${mapped}" == "AskUserQuestion" ]] || [[ "${mapped}" == "TodoWrite" ]]; then
		if [[ "${spec}" != "*" ]]; then
			warn "${mapped} does not support specifiers in Claude; skipping ${scope}.${key}.${spec}"
			return 0
		fi
		rule="${mapped}"
	else
		local first_tool="${mapped%%|*}"
		local second_tool="${mapped##*|}"

		if [[ "${spec}" == "*" ]]; then
			rule="${first_tool}"
			append_rule_once "${target_file}" "${rule}"
			if [[ "${mapped}" == *"|"* ]]; then
				append_rule_once "${target_file}" "${second_tool}"
			fi
			return 0
		fi

		rule="${first_tool}(${spec})"
		append_rule_once "${target_file}" "${rule}"

		if [[ "${mapped}" == *"|"* ]]; then
			append_rule_once "${target_file}" "${second_tool}(${spec})"
		fi

		return 0
	fi

	append_rule_once "${target_file}" "${rule}"
}

convert_permission_to_claude_lists() {
	local permission_json="$1"
	local scope="$2"
	local allow_file="$3"
	local ask_file="$4"
	local deny_file="$5"
	local allow_only="${6:-0}"

	local key
	while IFS= read -r key; do
		local value_type
		value_type="$(jq -r --arg k "${key}" '.[$k] | type' <<<"${permission_json}")"

		if [[ "${value_type}" == "string" ]]; then
			local action
			action="$(jq -r --arg k "${key}" '.[$k]' <<<"${permission_json}")"

			case "${action}" in
			allow) emit_claude_rule "${key}" "*" "${action}" "${allow_file}" "${scope}" ;;
			ask)
				if [[ "${allow_only}" == "1" ]]; then
					warn "${scope}.${key} uses ask, but skill allowed-tools supports allow only; skipping"
				else
					emit_claude_rule "${key}" "*" "${action}" "${ask_file}" "${scope}"
				fi
				;;
			deny)
				if [[ "${allow_only}" == "1" ]]; then
					warn "${scope}.${key} uses deny, but skill allowed-tools supports allow only; skipping"
				else
					emit_claude_rule "${key}" "*" "${action}" "${deny_file}" "${scope}"
				fi
				;;
			*) warn "invalid action '${action}' in ${scope}.${key}; skipping" ;;
			esac
			continue
		fi

		if [[ "${value_type}" == "object" ]]; then
			local pattern
			while IFS= read -r pattern; do
				local action
				action="$(jq -r --arg k "${key}" --arg p "${pattern}" '.[$k][$p]' <<<"${permission_json}")"

				case "${action}" in
				allow) emit_claude_rule "${key}" "${pattern}" "${action}" "${allow_file}" "${scope}" ;;
				ask)
					if [[ "${allow_only}" == "1" ]]; then
						warn "${scope}.${key}.${pattern} uses ask, but skill allowed-tools supports allow only; skipping"
					else
						emit_claude_rule "${key}" "${pattern}" "${action}" "${ask_file}" "${scope}"
					fi
					;;
				deny)
					if [[ "${allow_only}" == "1" ]]; then
						warn "${scope}.${key}.${pattern} uses deny, but skill allowed-tools supports allow only; skipping"
					else
						emit_claude_rule "${key}" "${pattern}" "${action}" "${deny_file}" "${scope}"
					fi
					;;
				*) warn "invalid action '${action}' in ${scope}.${key}.${pattern}; skipping" ;;
				esac
			done < <(jq -r --arg k "${key}" '.[$k] | keys[]' <<<"${permission_json}")
			continue
		fi

		warn "${scope}.${key} must be string or object, got ${value_type}; skipping"
	done < <(jq -r 'keys[]' <<<"${permission_json}")
}

convert_mcp_to_claude_lists() {
	local mcp_json="$1"
	local allow_file="$2"
	local ask_file="$3"
	local deny_file="$4"

	local claude_prefix="mcp__plugin_claude-code-home-manager"

	local entry
	while IFS= read -r entry; do
		local value_type
		value_type="$(jq -r --arg k "${entry}" '.[$k] | type' <<<"${mcp_json}")"

		if [[ "${value_type}" == "object" ]]; then
			local tool_pattern
			while IFS= read -r tool_pattern; do
				local action
				action="$(jq -r --arg s "${entry}" --arg t "${tool_pattern}" '.[$s][$t]' <<<"${mcp_json}")"
				local rule="${claude_prefix}_${entry}__${tool_pattern}"

				case "${action}" in
				allow) append_rule_once "${allow_file}" "${rule}" ;;
				ask) append_rule_once "${ask_file}" "${rule}" ;;
				deny) append_rule_once "${deny_file}" "${rule}" ;;
				*) warn "invalid action '${action}' in mcp.${entry}.${tool_pattern}; expected allow|ask|deny" ;;
				esac
			done < <(jq -r --arg s "${entry}" '.[$s] | keys[]' <<<"${mcp_json}")
		elif [[ "${value_type}" == "string" ]]; then
			local action
			action="$(jq -r --arg k "${entry}" '.[$k]' <<<"${mcp_json}")"
			local rule="${claude_prefix}_${entry}"

			case "${action}" in
			allow) append_rule_once "${allow_file}" "${rule}" ;;
			ask) append_rule_once "${ask_file}" "${rule}" ;;
			deny) append_rule_once "${deny_file}" "${rule}" ;;
			*) warn "invalid action '${action}' in mcp.${entry}; expected allow|ask|deny" ;;
			esac
		else
			warn "mcp.${entry} must be string or object, got ${value_type}; skipping"
		fi
	done < <(jq -r 'keys[]' <<<"${mcp_json}")
}

convert_mcp_to_opencode() {
	local mcp_json="$1"

	jq -c '
    [to_entries[] |
      if (.value | type) == "object" then
        .key as $server |
        .value | to_entries[] |
        {key: ($server + "_" + .key), value: .value}
      else
        .
      end
    ] | from_entries
  ' <<<"${mcp_json}"
}

render_json_array_from_file() {
	local file_path="$1"

	if [[ ! -s "${file_path}" ]]; then
		jq -n '[]'
		return 0
	fi

	jq -R -s 'split("\n") | map(select(length > 0)) | sort | unique' "${file_path}"
}

upsert_allowed_tools() {
	local file_path="$1"
	local allowed_tools_line="$2"
	local dry_run="$3"

	if [[ ! -f "${file_path}" ]]; then
		warn "skill file not found: ${file_path}"
		return 0
	fi

	local timestamp
	timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
	local tmp_path="${TMPDIR:-/tmp}/sync-permissions-${timestamp}-${RANDOM}.md"

	awk -v newline="${allowed_tools_line}" '
    NR == 1 {
      if ($0 == "---") {
        in_frontmatter = 1
      }
      print
      next
    }

    {
      if (in_frontmatter == 1) {
        if ($0 ~ /^allowed-tools:/) {
          print newline
          saw_allowed = 1
          next
        }

        if ($0 == "---") {
          if (saw_allowed == 0) {
            print newline
          }
          in_frontmatter = 0
          print
          next
        }
      }

      print
    }
  ' "${file_path}" >"${tmp_path}"

	if [[ "${dry_run}" == "1" ]]; then
		if ! cmp -s "${file_path}" "${tmp_path}"; then
			log "would update ${file_path}"
		fi
		rm -f "${tmp_path}"
		return 0
	fi

	mv "${tmp_path}" "${file_path}"
}

main() {
	local root
	root="${DOTFILES:-${HOME}/.dotfiles}"

	local source_file="${root}/config/agents/permissions.json"
	local dry_run="0"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--source)
			[[ $# -lt 2 ]] && fatal "--source requires an argument" 2
			source_file="$2"
			shift 2
			;;
		--dry-run)
			dry_run="1"
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			fatal "unknown option: $1" 2
			;;
		esac
	done

	command -v jq >/dev/null 2>&1 || fatal "jq is required"
	command -v rg >/dev/null 2>&1 || fatal "rg is required"

	[[ -f "${source_file}" ]] || fatal "source file not found: ${source_file}"

	local claude_settings="${root}/config/claude/settings.json"
	local opencode_config="${root}/config/opencode/opencode.json"
	local skills_dir="${root}/config/agents/skills"

	[[ -f "${claude_settings}" ]] || fatal "missing file: ${claude_settings}"
	[[ -f "${opencode_config}" ]] || fatal "missing file: ${opencode_config}"
	[[ -d "${skills_dir}" ]] || fatal "missing directory: ${skills_dir}"

	jq -e '.global | type == "object"' "${source_file}" >/dev/null || fatal "permissions.json must contain object field: global"
	jq -e '.mcp | type == "object"' "${source_file}" >/dev/null || fatal "permissions.json must contain object field: mcp"
	jq -e '.skills | type == "object"' "${source_file}" >/dev/null || fatal "permissions.json must contain object field: skills"

	local global_permission
	global_permission="$(jq -c '.global' "${source_file}")"

	local mcp_permission
	mcp_permission="$(jq -c '.mcp' "${source_file}")"

	local opencode_mcp
	opencode_mcp="$(convert_mcp_to_opencode "${mcp_permission}")"

	local skill_load_map
	skill_load_map="$(jq -c '.skills | keys | map({key: ., value: "allow"}) | from_entries' "${source_file}")"

	local opencode_permission
	opencode_permission="$(jq -n -c --argjson global "${global_permission}" --argjson mcp "${opencode_mcp}" --argjson load "${skill_load_map}" '
    $global + $mcp
    | if (.skill | type) == "object" then
        .skill = (.skill + $load)
      elif (.skill | type) == "string" then
        .skill = ({"*": .skill} + $load)
      elif (.skill == null) then
        . + {skill: $load}
      else
        . + {skill: $load}
      end
  ' </dev/null)"

	local timestamp
	timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

	local allow_file="${TMPDIR:-/tmp}/sync-permissions-${timestamp}-${RANDOM}-allow.txt"
	local ask_file="${TMPDIR:-/tmp}/sync-permissions-${timestamp}-${RANDOM}-ask.txt"
	local deny_file="${TMPDIR:-/tmp}/sync-permissions-${timestamp}-${RANDOM}-deny.txt"
	: >"${allow_file}"
	: >"${ask_file}"
	: >"${deny_file}"

	convert_permission_to_claude_lists "${global_permission}" "global" "${allow_file}" "${ask_file}" "${deny_file}"
	convert_mcp_to_claude_lists "${mcp_permission}" "${allow_file}" "${ask_file}" "${deny_file}"

	local claude_allow
	local claude_ask
	local claude_deny
	claude_allow="$(render_json_array_from_file "${allow_file}")"
	claude_ask="$(render_json_array_from_file "${ask_file}")"
	claude_deny="$(render_json_array_from_file "${deny_file}")"

	local claude_tmp="${TMPDIR:-/tmp}/sync-permissions-${timestamp}-${RANDOM}-claude.json"
	jq --argjson allow "${claude_allow}" --argjson ask "${claude_ask}" --argjson deny "${claude_deny}" '
    .permissions = ((.permissions // {}) + {
      allow: $allow,
      ask: $ask,
      deny: $deny
    })
  ' "${claude_settings}" >"${claude_tmp}"

	local opencode_tmp="${TMPDIR:-/tmp}/sync-permissions-${timestamp}-${RANDOM}-opencode.json"
	jq --argjson permission "${opencode_permission}" '.permission = $permission' "${opencode_config}" >"${opencode_tmp}"

	if [[ "${dry_run}" == "1" ]]; then
		if ! cmp -s "${claude_settings}" "${claude_tmp}"; then
			log "would update ${claude_settings}"
		fi

		if ! cmp -s "${opencode_config}" "${opencode_tmp}"; then
			log "would update ${opencode_config}"
		fi
	else
		mv "${claude_tmp}" "${claude_settings}"
		mv "${opencode_tmp}" "${opencode_config}"
	fi

	local skill_name
	while IFS= read -r skill_name; do
		local skill_permission
		skill_permission="$(jq -c --arg name "${skill_name}" '.skills[$name]' "${source_file}")"

		local skill_allow_file="${TMPDIR:-/tmp}/sync-permissions-${timestamp}-${RANDOM}-${skill_name}-allow.txt"
		: >"${skill_allow_file}"

		convert_permission_to_claude_lists "${skill_permission}" "skills.${skill_name}" "${skill_allow_file}" "/dev/null" "/dev/null" "1"

		local allowed_tools
		allowed_tools="$(jq -R -r -s 'split("\n") | map(select(length > 0)) | sort | unique | join(" ")' "${skill_allow_file}")"

		if [[ -z "${allowed_tools}" ]]; then
			warn "no Claude-compatible allow rules generated for skill '${skill_name}', leaving file unchanged"
			rm -f "${skill_allow_file}"
			continue
		fi

		local skill_file="${skills_dir}/${skill_name}/SKILL.md"
		upsert_allowed_tools "${skill_file}" "allowed-tools: ${allowed_tools}" "${dry_run}"

		rm -f "${skill_allow_file}"
	done < <(jq -r '.skills | keys[]' "${source_file}")

	rm -f "${allow_file}" "${ask_file}" "${deny_file}"
	if [[ "${dry_run}" == "1" ]]; then
		rm -f "${claude_tmp}" "${opencode_tmp}"
	fi

	if [[ "${dry_run}" == "1" ]]; then
		log "dry-run complete"
	else
		log "sync complete"
	fi
}

main "$@"
