---
name: pr-description
description: |
  Use when writing, rewriting, or updating a pull request description.
  Use this skill's explicit PR template unless the user provides a different
  template for the current task, keep the result concise and human-readable,
  explain why the change exists, reject generic project checks from `## Testing`,
  omit that section when no change-specific validation remains, format prose for
  GitHub's PR field without semantic line breaks, and ask the user for motivation
  before updating the PR when they have not explicitly provided it.
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
4. Apply the GitHub output formatting gate.
5. Apply the Testing evidence gate.
6. Write the shortest description that gives reviewers useful context.

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

## GitHub Output Formatting Gate

[GitHub renders single newlines as visible line breaks][github-line-breaks]
in issue and pull request fields.
Semantic line breaks that are harmless in a Markdown file therefore produce
ragged prose in a PR description.

For the PR body returned to the user or sent to GitHub:

- Keep each prose paragraph on one physical source line.
- Let GitHub wrap prose for the viewer's available width.
- Do not add semantic line breaks or wrap prose to a source line-length limit.
- Use blank lines only to separate paragraphs or other Markdown blocks.
- Keep the structural newlines required by headings, lists, block quotes,
  tables, and fenced code blocks.
- Keep each list item on one physical line unless it intentionally contains
  a nested block.
- Before returning or updating the body, scan for and join accidental newlines
  inside prose paragraphs and list items.

When the `markdown` skill is also loaded,
this gate overrides its Semantic Line Breaks guidance for the generated PR body.
Continue following its other Markdown structure and formatting guidance.

[github-line-breaks]: https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#line-breaks

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

## Testing Evidence Gate

`## Testing` describes change-specific coverage and exercised behavior.
It is not a command log or proof that the author completed required checks.

Before returning or updating a PR body:

1. Draft the candidate validation claims.
2. Remove every standard project command, check name,
   and generic pass result from the candidate claims,
   even when it appears beside useful evidence.
   This includes formatters, linters, type checks, complete test suites,
   `make check`, `just check`, `just test`, `go test ./...`, `npm test`,
   "CI passed", and "all tests passed".
   Preserve only the change-specific coverage or exercised behavior
   from a mixed claim.
3. Keep the remaining claim only when it identifies both
   the relevant behavior or scenario and how it was covered.
   Useful evidence includes new or changed automated coverage,
   a reproduced regression, an exercised user or operational flow,
   or a relevant edge case or failure mode.
4. If no claim remains, remove the entire `## Testing` section.

Apply this gate regardless of whether a baseline command ran locally,
in CI, or both.
Completion rules may still require those commands.
Report them in the agent handoff; do not copy them into the PR body.

This is invalid because it only records baseline commands:

```md
## Testing

- Ran `make check`.
- Ran `go test ./...`.
```

This is useful because it names the coverage and behavior:

```md
## Testing

- Added regression coverage for refreshing an expired access token.
- Reproduced the stale-cache failure and verified the second request refreshed it.
```

## PR Template

Use this exact template structure for PR descriptions.
Delete sections that would be empty before returning or updating the PR:

<!-- markdownlint-disable MD013 -->
```md
## Motivation

Describe what is the motivation behind the proposed changes. If possible reference the current solution/state of affairs. This must be explicitly provided by the user or by a user-referenced issue/ticket. Do not infer it from the diff.

## Summary

Recap of the most important code changes. If the solution is more complex and requires explanation do it here. Unexpected things or side quests should be documented here. Use completed tense, for example `Added ...`, not `Add ...`.

## Related Changes

List related changes from other PRs (if any).

## Testing

How was this change covered? Only units? Integration? End-to-end? Manual? Include only claims that pass the Testing evidence gate: name the relevant behavior or scenario and how it was covered. Never list standard project checks or generic pass results. If no change-specific validation remains, remove this section. Use completed tense for test coverage statements.

## Release Notes

If this change should be part of the Release Notes, **replace this entire paragraph** with 1-3 sentences about the changes. Use completed tense.

Does this PR contain any breaking changes? If so, add `## Breaking Changes` header and list the introduced changes there.
```
<!-- markdownlint-enable MD013 -->

## What Not to Write

- Do not list changed files.
- Do not restate the diff line by line.
- Do not pad the description with implementation trivia.
- Do not use generic filler like "This PR updates several files".
- Do not add AI-generation disclaimers.
- Do not preserve template instructions in the final PR description.
- Do not use semantic line breaks or source-width wrapping in PR body prose.
- Do not describe running a standard project check as test coverage.
- Do not leave a standard command, check name,
  or generic pass result in a mixed Testing claim.
- Do not keep `Testing` when no change-specific evidence remains.

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
- Is each prose paragraph and ordinary list item on one physical source line?
- Did you remove every empty section instead of writing filler?
- Does the PR body use completed tense consistently?
- Did `Motivation` come from the user or a user-referenced issue/ticket?
- If not, did you stop before updating the PR and ask the user?
- Does every `Testing` claim name relevant behavior or a scenario
  and explain how it was covered?
- Did you strip all standard checks and generic pass results,
  including from otherwise useful claims?
- Did you remove `Testing` if no change-specific evidence remained?
- If the rationale was unclear, did you ask before updating?

## Coordinate With Other Skills

- When creating a PR end to end, also load `create-github-pr`.
- When `markdown` is also loaded,
  the GitHub Output Formatting Gate in this skill takes precedence
  over its Semantic Line Breaks guidance for PR body output.
