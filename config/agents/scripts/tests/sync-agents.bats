#!/usr/bin/env bats

# jq expressions use --arg values, not shell interpolation.
# shellcheck disable=SC2016

setup() {
  bats_require_minimum_version 1.5.0
  script="${BATS_TEST_DIRNAME}/../sync-agents.sh"
  source_dir="${BATS_TEST_TMPDIR}/source"
  output_root="${BATS_TEST_TMPDIR}/output"
  mkdir -p -- "${source_dir}"
  cp -- "${BATS_TEST_DIRNAME}/../../agents/code-reviewer.md" "${source_dir}/"
  cp -- "${BATS_TEST_DIRNAME}/../../agents/docs-analyzer.md" "${source_dir}/"
}

@test "generates consumer metadata and review instructions for each harness" {
  cp -- "${BATS_TEST_DIRNAME}/../../agents/"*.md "${source_dir}/"
  run_sync
  [[ "${status}" -eq 0 ]]
  [[ -f "${output_root}/codex/standards-guardian.toml" ]]

  local source name harness generated header
  for source in "${source_dir}/"*.md; do
    name="${source##*/}"
    name="${name%.md}"
    generated="${output_root}/codex/${name}.toml"
    tomlq -e --arg name "${name}" \
      '.name == $name and (.developer_instructions | length > 0)' "${generated}"
    if [[ "${name}" != code-simplifier ]]; then
      tomlq -e '.sandbox_mode == "read-only"' "${generated}"
    fi
    for harness in claude-code opencode; do
      generated="${output_root}/${harness}/${name}.md"
      header="${BATS_TEST_TMPDIR}/header.yaml"
      awk '/^---$/ { count++; next } count == 1 { print } count == 2 { exit }' \
        "${generated}" >"${header}"
      yq -e --arg name "${name}" '.name == $name and ."harness-config" == null' "${header}"
      if [[ "${name}" != code-simplifier ]]; then
        if [[ "${harness}" == claude-code && "${name}" != review-coordinator ]]; then
          yq -e '.tools == "Read, Glob, Grep, Skill, WebFetch, WebSearch"' "${header}"
        elif [[ "${harness}" == opencode ]]; then
          yq -e '.permission.edit == "deny" and .permission.bash == "deny"' "${header}"
        fi
      fi
    done
  done
}

@test "coordinator inherits reasoning and can delegate only to review specialists" {
  cp -- "${BATS_TEST_DIRNAME}/../../agents/review-coordinator.md" "${source_dir}/"
  run_sync
  [[ "${status}" -eq 0 ]]

  tomlq -e '.model == null and .model_reasoning_effort == null and .sandbox_mode == "read-only"' \
    "${output_root}/codex/review-coordinator.toml"

  local harness header
  for harness in claude-code opencode; do
    header="${BATS_TEST_TMPDIR}/${harness}.yaml"
    awk '/^---$/ { count++; next } count == 1 { print } count == 2 { exit }' \
      "${output_root}/${harness}/review-coordinator.md" >"${header}"
    if [[ "${harness}" == claude-code ]]; then
      yq -e '.effort == null and .model == "inherit" and
        (.tools | contains("Agent(standards-guardian, code-reviewer, spec-reviewer, test-analyzer, silent-failure-hunter, type-design-analyzer, docs-analyzer, security-reviewer)"))' \
        "${header}"
    else
      yq -e '.model == null and .reasoningEffort == null and .permission.task == {
        "*": "deny", "standards-guardian": "allow", "code-reviewer": "allow", "spec-reviewer": "allow",
        "test-analyzer": "allow", "silent-failure-hunter": "allow",
        "type-design-analyzer": "allow", "docs-analyzer": "allow", "security-reviewer": "allow"
      }' "${header}"
    fi
  done
}

@test "removes retired outputs owned by the generator in every harness" {
  run_sync
  [[ "${status}" -eq 0 ]]
  rm -- "${source_dir}/docs-analyzer.md"

  run_sync
  [[ "${status}" -eq 0 ]]
  [[ ! -e "${output_root}/claude-code/docs-analyzer.md" ]]
  [[ ! -e "${output_root}/opencode/docs-analyzer.md" ]]
  [[ ! -e "${output_root}/codex/docs-analyzer.toml" ]]
  [[ -f "${output_root}/codex/code-reviewer.toml" ]]
  jq -e '.files | has("docs-analyzer.toml") | not' "${output_root}/codex/.sync-agents.json"
}

@test "preserves legacy and user-created agents without ownership evidence" {
  mkdir -p -- "${output_root}/codex"
  printf 'user-maintained agent\n' >"${output_root}/codex/comment-analyzer.toml"

  run_sync
  [[ "${status}" -eq 0 ]]
  [[ "$(cat "${output_root}/codex/comment-analyzer.toml")" = "user-maintained agent" ]]
  [[ "${stderr}" == *"preserved unmanaged agent without a current source:"* ]]
  jq -e '.files | has("comment-analyzer.toml") | not' "${output_root}/codex/.sync-agents.json"
}

@test "an unowned collision stops before publishing any harness" {
  mkdir -p -- "${output_root}/codex"
  printf 'user-maintained agent\n' >"${output_root}/codex/code-reviewer.toml"

  run_sync
  [[ "${status}" -eq 1 ]]
  [[ "${stderr}" == *"unowned agent differs from generated content:"* ]]
  [[ "$(cat "${output_root}/codex/code-reviewer.toml")" = "user-maintained agent" ]]
  [[ ! -e "${output_root}/claude-code/code-reviewer.md" ]]
}

@test "an invalid later destination does not publish earlier harnesses" {
  mkdir -p -- "${output_root}"
  printf 'keep\n' >"${output_root}/opencode"

  run_sync
  [[ "${status}" -eq 1 ]]
  [[ "${stderr}" == *"destination ancestor is not a writable directory:"* ]]
  [[ ! -e "${output_root}/claude-code/code-reviewer.md" ]]
  [[ "$(cat "${output_root}/opencode")" = keep ]]
}

@test "adopts byte-identical legacy files without an override" {
  run_sync
  [[ "${status}" -eq 0 ]]
  rm -- "${output_root}/codex/.sync-agents.json"

  run_sync
  [[ "${status}" -eq 0 ]]
  jq -e '.files | has("code-reviewer.toml")' "${output_root}/codex/.sync-agents.json"
}

@test "an explicit adoption replaces only files with current source names" {
  mkdir -p -- "${output_root}/codex"
  printf 'legacy generation\n' >"${output_root}/codex/code-reviewer.toml"
  printf 'keep\n' >"${output_root}/codex/custom.toml"

  run --separate-stderr "${script}" --source "${source_dir}" \
    --output-root "${output_root}" --adopt-existing
  [[ "${status}" -eq 0 ]]
  tomlq -e '.name == "code-reviewer"' "${output_root}/codex/code-reviewer.toml"
  [[ "$(cat "${output_root}/codex/custom.toml")" = keep ]]
}

@test "a modified retired file stops the run before any harness changes" {
  run_sync
  [[ "${status}" -eq 0 ]]
  cp -- "${output_root}/claude-code/code-reviewer.md" "${BATS_TEST_TMPDIR}/before.md"
  rm -- "${source_dir}/docs-analyzer.md"
  printf '\nUser change.\n' >>"${output_root}/codex/docs-analyzer.toml"
  printf '\nNew source instruction.\n' >>"${source_dir}/code-reviewer.md"

  run_sync
  [[ "${status}" -eq 1 ]]
  [[ "${stderr}" == *"modified managed file; preserve its changes before syncing:"* ]]
  cmp -- "${BATS_TEST_TMPDIR}/before.md" "${output_root}/claude-code/code-reviewer.md"
  [[ -f "${output_root}/claude-code/docs-analyzer.md" ]]
  [[ -f "${output_root}/codex/docs-analyzer.toml" ]]
}

@test "preserves edits to a current generated agent" {
  run_sync
  [[ "${status}" -eq 0 ]]
  printf '\nUser change.\n' >>"${output_root}/opencode/code-reviewer.md"
  cp -- "${output_root}/opencode/code-reviewer.md" "${BATS_TEST_TMPDIR}/edited.md"

  run_sync
  [[ "${status}" -eq 1 ]]
  cmp -- "${BATS_TEST_TMPDIR}/edited.md" "${output_root}/opencode/code-reviewer.md"
}

@test "an invalid source does not publish other staged changes" {
  run_sync
  [[ "${status}" -eq 0 ]]
  cp -- "${output_root}/codex/code-reviewer.toml" "${BATS_TEST_TMPDIR}/before.toml"
  printf '\nNew source instruction.\n' >>"${source_dir}/code-reviewer.md"
  printf '%s\n' '---' 'name: invalid' 'description: Missing a body.' '---' \
    >"${source_dir}/invalid.md"

  run_sync
  [[ "${status}" -eq 1 ]]
  [[ "${stderr}" == *"missing agent body"* ]]
  cmp -- "${BATS_TEST_TMPDIR}/before.toml" "${output_root}/codex/code-reviewer.toml"
  [[ ! -e "${output_root}/claude-code/invalid.md" ]]
}

@test "rejects path traversal in an ownership manifest" {
  run_sync
  [[ "${status}" -eq 0 ]]
  printf 'keep\n' >"${output_root}/victim"
  jq '.files["../victim"] = ("a" * 64)' "${output_root}/codex/.sync-agents.json" \
    >"${BATS_TEST_TMPDIR}/invalid.json"
  mv -- "${BATS_TEST_TMPDIR}/invalid.json" "${output_root}/codex/.sync-agents.json"

  run_sync
  [[ "${status}" -eq 1 ]]
  [[ "${stderr}" == *"invalid ownership manifest or different source directory:"* ]]
  [[ "$(cat "${output_root}/victim")" = keep ]]
}

@test "does not remove a managed path replaced with a symlink" {
  run_sync
  [[ "${status}" -eq 0 ]]
  rm -- "${source_dir}/docs-analyzer.md" "${output_root}/codex/docs-analyzer.toml"
  printf 'keep\n' >"${BATS_TEST_TMPDIR}/victim"
  ln -s -- "${BATS_TEST_TMPDIR}/victim" "${output_root}/codex/docs-analyzer.toml"

  run_sync
  [[ "${status}" -eq 1 ]]
  [[ "${stderr}" == *"refusing to replace non-regular managed file:"* ]]
  [[ -L "${output_root}/codex/docs-analyzer.toml" ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/victim")" = keep ]]
}

@test "an empty source directory cannot retire the whole roster" {
  run_sync
  [[ "${status}" -eq 0 ]]
  rm -- "${source_dir}/"*.md

  run_sync
  [[ "${status}" -eq 1 ]]
  [[ "${stderr}" == *"no agent source files found"* ]]
  [[ -f "${output_root}/codex/code-reviewer.toml" ]]
  [[ -f "${output_root}/codex/docs-analyzer.toml" ]]
}

@test "unchanged synchronization does not replace generated files" {
  run_sync
  [[ "${status}" -eq 0 ]]
  local before
  before="$(stat -c '%i' "${output_root}/codex/code-reviewer.toml")"

  run_sync
  [[ "${status}" -eq 0 ]]
  [[ "$(stat -c '%i' "${output_root}/codex/code-reviewer.toml")" = "${before}" ]]
}

@test "an empty output root fails instead of writing live configuration" {
  run --separate-stderr "${script}" --source "${source_dir}" --output-root ''

  [[ "${status}" -eq 2 ]]
  [[ "${stderr}" == *"--output-root requires a directory"* ]]
}

run_sync() {
  run --separate-stderr "${script}" --source "${source_dir}" --output-root "${output_root}"
}
