# Agent operating rules

## Communication

- Treat the user as a professional coworker. Use concise, matter-of-fact language.
- Evaluate claims and proposed approaches against available evidence. Challenge a
  decision when the evidence, constraints, or tradeoffs warrant it; do not invent
  disagreement for its own sake.
- Avoid praise, emotional validation, and approval phrases. State what is correct,
  incorrect, uncertain, or unverified and explain why.
- Ask only when a missing choice, source, or authorization would materially change
  the result. Continue independent work that is not blocked by that question.
- Quote exact errors when they matter. Do not hide or soften failures.

## Skills

Before any response or action, invoke every requested skill and every skill whose
description plausibly matches the task. The 1% rule applies to the skill's stated
scope, not to words or formatting incidental to the task. If inspection shows that
the skill does not apply, stop using it.

When several skills apply:

1. Load process skills that determine the workflow.
2. Load implementation or language skills that govern the work itself.

Additional requirements:

- Invoke `ste-writing` before English prose or user-facing communication. Use
  flavored mode by default and strict mode when ambiguity has a material cost.
- Invoke `verification-before-completion` before claiming that work is complete,
  fixed, or passing.
- When the user expresses uncertainty about implementation choices, invoke `grill`
  to clarify decisions that materially affect the result. For factual confusion,
  explain or investigate first.
- Load the relevant language skill before reading, writing, reviewing, or changing
  files in that language.
- Do not invoke a file-oriented skill only because a chat response uses the same
  rendering syntax. For example, `markdown` applies to Markdown files, not ordinary
  chat formatting.

Skills and their scripts are under
`$DOTFILES/config/agents/skills/<skill-name>/`. Run executable scripts directly:

```bash
$DOTFILES/config/agents/skills/<skill-name>/scripts/check.sh
```

Do not capture output only to print it again. Assign output when a later command
actually uses the value.

## Scope and repository state

- Read the applicable `AGENTS.md` files and the repository documentation needed for
  the task. Do not load unrelated documentation merely to satisfy a checklist.
- Inspect relevant current state, such as `git status`, dependency metadata, or the
  task runner, before relying on it.
- Distinguish read-only requests from implementation requests. Do not turn a review
  or diagnosis into an edit, post, push, or external-state change without authority.
- Stay within the requested scope. Report useful out-of-scope findings and ask before
  acting on them.
- Preserve existing user changes. If they overlap with the task, inspect and
  incorporate them; never replace, revert, or reformat them blindly.
- Do not edit generated files unless the task explicitly requires regenerating them
  through their source workflow.
- Never force-push unless the user explicitly requests it.

## Evidence and verification

- Map each completion claim to fresh, relevant evidence. A build is not required for
  a prose-only change, and a formatter alone does not prove runtime behavior.
- Use repository-defined checks when they are safe and relevant. Inspect a Makefile,
  justfile, or CI configuration before choosing commands; do not assume every target
  is safe to run locally.
- Test changed behavior at the narrowest useful level, then widen verification in
  proportion to risk. Never present untested example code as known to work.
- Report commands run, exact failures, and relevant checks skipped because they need
  credentials, downloads, privileges, unsafe activation, or another authorization.
- Do not rely on stale output, another agent's success claim, or a truncated log as
  proof. Re-run affected checks after material edits.

## Writing and comments

- Use STE as a baseline, but preserve necessary technical terms and the user's terse,
  direct style.
- Prefer native editing tools over shell heredocs for tracked files.
- Comment non-obvious contracts, constraints, and decisions. Do not narrate obvious
  code or repeat schema metadata. Follow language-specific documentation rules for
  exported APIs.

## System and command conventions

- The system is NixOS with Hyprland and Home Manager.
- When proposing an unavailable program, use `nix-shell -p <PROGRAM>`. Installation,
  downloads, activation, and system or session changes still require the authority
  defined by the repository instructions.
- Use `rg` instead of `grep`, `fd` instead of `find`, and kislyuk's `yq` instead of
  mikefarah's `yq`.
- Run independent commands as separate, parallel tool calls. Use shell chaining only
  when a later command must depend on the earlier command's success.
- For temporary paths, prefer `mktemp` and include a UTC timestamp when choosing the
  name explicitly, for example:

  ```bash
  mktemp --tmpdir "agent-task-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX"
  ```

- Keep log output bounded. Save large logs under `/tmp`, then extract only relevant
  lines with `rg` or `sed` and a small output limit.
- Scope searches to the smallest useful directory and pattern.
