---
name: pr-description
description: |
  Use when writing, rewriting, or updating a pull request description.
  Use this skill's explicit PR template unless the user provides a different
  template for the current task, keep the result concise and human-readable,
  explain why the change exists, and ask the user for motivation before updating
  the PR when the user has not explicitly provided it.
---

# PR Description

Write pull request descriptions for reviewers,
not for diff viewers.
PR descriptions are for humans:
make them as short as possible while still readable.

The diff already shows which files changed.
The description should explain the reason for the change,
the behavior or reviewer-relevant outcome,
and any important caveats.

## Workflow

1. Verify the source of truth.
2. Check whether the user provided a task-specific PR template.
3. Extract the user-provided why before drafting the description.
4. Write the shortest description that gives reviewers useful context.

## Verify the Source of Truth

- Review the branch diff, commits, linked issue, and existing PR metadata first.
- Reuse concrete context that already exists.
- Do not invent product rationale, incident context, or follow-up work.
- Do not treat implementation details, commit messages, branch names,
  or inferred benefits as PR motivation.

## Motivation Gate

`## Motivation` must be based on motivation explicitly supplied by the user,
an issue or ticket referenced by the user,
or an existing PR description written before your current edit.

If the user only described what to build,
what changed,
or which files to edit,
that is not enough motivation.
Stop and ask for the missing motivation before writing or updating the PR body.

Ask one concise question, for example:

```text
What motivation should I put in the PR?
The diff shows what changed, but I need the user-facing or reviewer-facing reason
before I update `## Motivation`.
```

## Follow the Template

- Use the explicit PR template in this skill unless the user provides a different
  template for the current task.
- Keep only sections with useful content.
- If any section is empty, remove the section header and body entirely.
- Never keep empty headers.
- Never write filler such as `none`, `N/A`, `not applicable`, or `no changes`.
- Do not add extra sections except `## Breaking Changes` when needed.

## What to Write

- Lead with why this change exists.
- State the reviewer-relevant outcome:
  behavior change, bug fix, risk reduction, or operational impact.
- Use completed tense for PR body descriptions:
  write `Added`, `Updated`, `Removed`, `Fixed`, or similar past-tense verbs.
  Do not use imperative verbs like `Add`, `Update`, `Remove`, or `Fix`
  in `Summary`, `Testing`, or `Release Notes`.
- Mention constraints, rollout notes, or follow-up only if they matter to review.
- Keep it concise.
  A short paragraph or a few bullets is usually enough.

## PR Template

Use this exact template structure for PR descriptions.
Delete sections that would be empty before returning or updating the PR:

```md
## Motivation

Describe what is the motivation behind the proposed changes.
If possible reference the current solution/state of affairs.
This must be explicitly provided by the user or by a user-referenced issue/ticket.
Do not infer it from the diff.

## Summary

Recap of the most important code changes.
If the solution is more complex and requires explanation do it here.
Unexpected things or side quests should be documented here.
Use completed tense, for example `Added ...`, not `Add ...`.

## Related Changes

List related changes from other PRs (if any).

## Testing

How was this change covered? Only units? Integration? End-to-end? Manual?
Mention only reviewer-useful validation for this change:
new or changed test coverage, reproduced bug scenarios, exercised user flows,
manual checks, edge cases, or failure modes.
Do not list mandatory project checks that CI runs anyway,
such as formatting, linting, type checks, `just check`, `just test`,
`go test ./...`, `npm test`, or equivalent baseline commands.
If there is no validation beyond those mandatory checks,
remove this section.
Use completed tense for test coverage statements.

## Release Notes

If this change should be part of the Release Notes,
**replace this entire paragraph** with 1-3 sentences about the changes.
Use completed tense.

Does this PR contain any breaking changes?
If so, add `## Breaking Changes` header and list the introduced changes there.
```

## What Not to Write

- Do not list changed files.
- Do not restate the diff line by line.
- Do not pad the description with implementation trivia.
- Do not use generic filler like "This PR updates several files".
- Do not add AI-generation disclaimers.
- Do not preserve template instructions in the final PR description.
- Do not fill `Testing` with mandatory CI-equivalent commands.

## If the Why Is Unclear

Do not guess.
Do not update the PR description yet.

Treat motivation as unclear whenever it was not explicitly provided by the user
or by a user-referenced issue/ticket,
even if the diff makes the technical benefit obvious.

Ask the user the minimum set of questions needed to recover the missing context.
Focus on questions like:

- What problem does this change solve?
- Why is this needed now?
- What should reviewers pay attention to?
- Is there any user-visible, operational, or risky behavior change?

Once those answers are known,
write the description from them.

## Final Check

- Does the first line tell the reviewer why this PR exists?
- Did you avoid file inventories and diff narration?
- Is the result as short as possible while still readable?
- Did you remove every empty section instead of writing filler?
- Does the PR body use completed tense consistently?
- Did `Motivation` come from the user or a user-referenced issue/ticket?
- If not, did you stop before updating the PR and ask the user?
- Does `Testing` omit mandatory CI-equivalent checks and mention only
  reviewer-useful validation when included?
- If the rationale was unclear, did you ask before updating?

## Coordinate With Other Skills

- When creating a PR end to end, also load `create-github-pr`.
