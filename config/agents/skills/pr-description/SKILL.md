---
name: pr-description
description: |
  Use when writing, rewriting, or updating a pull request description.
  Explain the supplied reason, keep only reviewer-relevant sections, and include only
  change-specific validation in Testing. Omit unsupported motivation and ask after PR creation.
  Writing to GitHub requires an explicit create or update request.
---

# PR description

Write for reviewers.
The diff shows what changed.
The body explains why it matters, the important outcome, and any review risk.

## Source gate

Inspect the request, linked issue or ticket, branch diff, commits, and existing PR body.
Use only rationale supported by those sources.
Before using private issue, ticket, or repository context, check the target
repository's visibility. Do not transfer private details into a public pull
request unless the user explicitly supplied or approved that text for publication.

A user-described defect, limitation, operational need, or desired outcome
is valid motivation even when the user did not label it as such.

If the reason is unknown or unclear, omit `## Motivation` and continue with the supported content.
Missing motivation does not block PR creation or an authorized body update.
For a new PR, first create it, verify success, and report its URL.
Then ask one focused question about the missing motivation.
Treat the user's answer as a continuation of that task and add the supported motivation to the PR.

Honor an explicit request to omit motivation or use another template.
Skip the motivation question in those cases.

An explicit request to create or update a PR authorizes its body write within that task.
A request only to draft or review text does not authorize an external write.

## Default template

Use this structure unless the user supplies a different template:

```md
## Motivation

<Why this change is needed.>

## Summary

<Reviewer-relevant outcome and important implementation context.>

## Related Changes

<Related pull requests or coordinated changes.>

## Testing

<Change-specific behavior or scenario and how it was covered.>

## Release Notes

<One to three release-note sentences.>

## Breaking Changes

<Compatibility impact and required action.>
```

Delete every empty section.
Do not use `N/A`, `none`, or retained template instructions.
Add no extra section unless it improves review or the user requests it.

## Content rules

- Keep the body as short as the review context permits.
- Use completed tense for changes and validation.
- Do not list files or narrate the diff.
- Do not invent product rationale, benefits, risks, or follow-up work.
- Keep each prose paragraph and ordinary list item on one physical line
  because GitHub issue fields render single newlines as visible breaks.

## Testing gate

`## Testing` records change-specific evidence, not routine project checks.
Keep a claim only when it names the relevant behavior or scenario and how it was covered.
Valid examples include a regression case, changed automated coverage,
an exercised user flow, or a relevant failure mode.

Remove command-only and generic claims such as `make check`,
`go test ./...`, `CI passed`, or `all tests passed`.
When a sentence mixes routine checks with useful evidence, keep only the useful evidence.
If no change-specific claim remains, remove `## Testing`.

Report routine verification in the implementation handoff instead.

## Final check

- The reason comes from an allowed source.
  Otherwise, omit the section. Also omit it when the user requests this.
- Each section helps the reviewer.
- Testing contains behavior and coverage, not a command log.
- Prose has no accidental source wrapping.
- Updating GitHub is within the user's stated authority.
