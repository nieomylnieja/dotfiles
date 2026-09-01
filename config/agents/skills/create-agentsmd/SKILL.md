---
name: create-agentsmd
description: |
  Create or revise AGENTS.md when the user explicitly asks for repository
  agent instructions. Inspect the existing hierarchy, preserve verified local
  rules, and do not invent setup, test, build, or deployment commands.
---

# Create or revise AGENTS.md

Write repository-specific operating instructions, not a generic project guide.
The nearest AGENTS.md controls its subtree. There is no required template.

## Inspect first

1. Read every AGENTS.md that applies to the target path.
2. Check `git status` and preserve unrelated user changes.
3. Read the repository overview and the files that define its workflows:
   build manifests, task runners, CI configuration, contribution guidance,
   and generated-file notices.
4. Identify the correct instruction file. Update an existing file when its
   scope is right. Add a nested file only when a subtree needs different rules.
5. Confirm each command from repository evidence. Run only safe checks that
   are needed to verify a claim.

Do not run install, deployment, activation, privileged, or system-changing
commands merely to discover their behavior. Mark a command as unverified when
safe verification is not possible.

## Write only useful rules

Include the smallest set that helps another agent work safely and correctly:

- the repository or subtree purpose and important entry points.
- the source-of-truth files and generated files that must not be edited.
- verified build, test, lint, and focused-test commands.
- scope, ownership, security, and working-tree constraints.
- project-specific conventions that are not obvious from nearby code.
- unsafe or external operations that require explicit authorization.

Omit generic advice, placeholder commands, unsupported assumptions, copied
templates, and facts already easy to discover from a standard manifest.
Do not add tests, deployment steps, or process requirements that the user did
not request and the repository does not require.

## Edit and verify

- Preserve existing user rules unless a higher-priority instruction conflicts.
- Resolve contradictions instead of adding an override paragraph above them.
- Prefer direct, testable statements with explicit scope.
- Link to durable repository documentation instead of copying long sections.
- Run Markdown and prose checks that apply to the changed file.
- Re-read the final hierarchy from root to target and check for conflicts.
- Report commands that were not run and why.
