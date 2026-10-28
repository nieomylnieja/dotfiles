---
name: create-agentsmd
description: |
  Create or revise AGENTS.md when the user explicitly asks for repository
  agent instructions. Inspect the existing hierarchy, preserve verified local
  rules, and do not invent setup, test, build, or deployment commands.
---

# Create or revise AGENTS.md

Keep guidance used by humans and agents in shared project documentation.
Use `AGENTS.md` for agent-specific rules and pointers to that documentation.
The nearest `AGENTS.md` controls its subtree. There is no required template.

## Inspect first

1. Read every `AGENTS.md` that applies to the target path.
2. Check `git status` and preserve unrelated user changes.
3. Read existing human documentation, such as `README.md`, `DEVELOPMENT.md`,
   `CONTRIBUTING.md`, and relevant guides under `docs/`.
   Check build manifests, task runners, CI configuration, and generated-file notices.
4. Identify the correct instruction file. Update an existing file when its
   scope is right. Add a nested file only when a subtree needs different rules.
5. Confirm each command from repository evidence. Run only safe checks that
   are needed to verify a claim.

Do not run install, deployment, activation, privileged, or system-changing
commands merely to discover their behavior. Mark a command as unverified when
safe verification is not possible.

## Share documentation with humans

- Give each shared topic one authoritative home in human documentation.
  This includes project context, setup, commands, workflows, and conventions.
- Link to the relevant file or section from `AGENTS.md` and state when the agent
  must read it. Use these pointers instead of copied or paraphrased guidance,
  including short command lists.
- When consolidating duplicate guidance, preserve its verified content in the
  shared document and replace the `AGENTS.md` copy with a pointer.
  Keep agent-specific constraints beside that pointer.
- When shared guidance needs corrections or additions, update its existing
  document within the requested scope. Create a shared document only when the
  content warrants one and the task permits it.

## Write only useful rules

Include the smallest set that helps another agent work safely and correctly:

- pointers to shared project context and verified development workflows.
- the source-of-truth files and generated files that must not be edited.
- scope, ownership, security, and working-tree constraints.
- agent-specific conventions that are not covered by shared documentation.
- unsafe or external operations that require explicit authorization.

Omit generic advice, placeholder commands, unsupported assumptions, copied
templates, and facts already easy to discover from a standard manifest.
Do not add tests, deployment steps, or process requirements that the user did
not request and the repository does not require.

## Edit and verify

- Preserve existing user rules unless a higher-priority instruction conflicts.
- Resolve contradictions instead of adding an override paragraph above them.
- Prefer direct, testable statements with explicit scope.
- Verify linked files and section anchors, and check for duplicated guidance
  across `AGENTS.md` and shared documentation.
- Run Markdown and prose checks that apply to the changed file.
- Re-read the final hierarchy from root to target and check for conflicts.
- Report commands that were not run and why.
