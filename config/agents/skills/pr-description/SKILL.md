---
name: pr-description
description: |
  Use when writing, rewriting, or updating a pull request description.
  Follow the repository's PR template when one exists, keep the result concise
  and human-readable, explain why the change exists, and ask clarifying
  questions before updating the PR if the rationale or context is unclear.
---

# PR Description

Write pull request descriptions for reviewers,
not for diff viewers.

The diff already shows which files changed.
The description should explain the reason for the change,
the behavior or reviewer-relevant outcome,
and any important caveats.

## Workflow

1. Verify the source of truth.
2. Check whether a PR template exists.
3. Extract the why before drafting the description.
4. Write the shortest description that gives reviewers useful context.

## Verify the Source of Truth

- Review the branch diff, commits, linked issue, and existing PR metadata first.
- Reuse concrete context that already exists.
- Do not invent product rationale, incident context, or follow-up work.

## Follow the Repository Template

- If the repository provides a PR template, use its structure.
- Keep the existing sections and headings.
- Fill only the sections that are relevant.
- If a section would be empty and the template does not require it,
  omit its contents rather than adding filler.
- Do not add extra sections unless the template clearly expects them.

## What to Write

- Lead with why this change exists.
- State the reviewer-relevant outcome:
  behavior change, bug fix, risk reduction, or operational impact.
- Mention constraints, rollout notes, or follow-up only if they matter to review.
- Keep it concise.
  A short paragraph or a few bullets is usually enough.

## Preferred Structure

When there is no stronger repository-specific template,
use this structure:

```md
## Motivation

Explain why this change is needed now.

Describe the current problem, limitation, or risk in the existing behavior.
Reference the current solution or state of affairs when that helps reviewers
understand the change.

## Summary

- State the main outcome of the change.
- Call out the reviewer-relevant behavior change or decision.
- Note an important caveat, rollout concern, or follow-up only if it matters.

## Testing

Describe only the meaningful verification performed beyond routine project checks.

Do not report standard test commands, lint runs, or CI-equivalent checks.
Focus on concrete evidence that gives reviewers confidence the change works in
practice.

If no such verification was performed, say that explicitly.
If verification is partial or incomplete, state the gap clearly.
```

### Testing Section Rules

- `Testing` must describe evidence, not baseline automation.
- Do not list routine project checks such as `make test`, `go test`,
  `npm test`, lint commands, or other expected CI checks.
- Include reviewer-useful verification such as reproduced bug scenarios,
  exercised user flows, integration behavior, manual validation,
  edge cases, failure modes, or before/after observations.
- If only routine checks were performed, say that no meaningful verification
  beyond baseline automation was done.

## What Not to Write

- Do not list changed files.
- Do not restate the diff line by line.
- Do not pad the description with implementation trivia.
- Do not use generic filler like "This PR updates several files".
- Do not add AI-generation disclaimers.

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
- Is the result short enough to scan quickly?
- Does `Testing` avoid routine project checks and report only meaningful evidence?
- If the rationale was unclear, did you ask before updating?

## Coordinate With Other Skills

- When creating a PR end to end, also load `create-github-pr`.
