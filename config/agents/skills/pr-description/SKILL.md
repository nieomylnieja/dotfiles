---
name: pr-description
description: |
  Use when writing, rewriting, or updating a pull request description.
  Use this skill's explicit PR template unless the user provides a different
  template for the current task, keep the result concise and human-readable,
  explain why the change exists, and ask clarifying questions before updating
  the PR if the rationale or context is unclear.
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
3. Extract the why before drafting the description.
4. Write the shortest description that gives reviewers useful context.

## Verify the Source of Truth

- Review the branch diff, commits, linked issue, and existing PR metadata first.
- Reuse concrete context that already exists.
- Do not invent product rationale, incident context, or follow-up work.

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
This should be always provided by the user, not you.

## Summary

Recap of the most important code changes.
If the solution is more complex and requires explanation do it here.
Unexpected things or side quests should be documented here.

## Related Changes

List related changes from other PRs (if any).

## Testing

How was this change covered? Only units? Integration? End-to-end? Manual?

## Release Notes

If this change should be part of the Release Notes,
**replace this entire paragraph** with 1-3 sentences about the changes.

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

## If the Why Is Unclear

Do not guess.
Do not update the PR description yet.

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
- Did `Motivation` come from the user or verified existing context?
- Does `Testing` describe the type of coverage or verification when included?
- If the rationale was unclear, did you ask before updating?

## Coordinate With Other Skills

- When creating a PR end to end, also load `create-github-pr`.
