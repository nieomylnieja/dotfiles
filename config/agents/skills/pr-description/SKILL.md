---
name: pr-description
description: |
  Use when writing, reviewing, or updating a pull request description.
  Explain the supplied reason, keep only reviewer-relevant sections, and include only
  change-specific validation in Testing. Omit unsupported motivation and ask after PR creation.
  Require independent review of the exact body before an authorized GitHub write.
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
- Describe the resulting change, not the implementation session. Keep merge and
  conflict-resolution history, setup progress, and routine check logs in the handoff.
  Keep a revision, dependency, or validation limit when it explains a review risk.
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

## Screenshots and attachments

Use GitHub-hosted attachments for images that only support the PR description.
Keep them outside the source tree unless the user requests repository assets.
When adding or migrating images, read the
[attachment workflow](references/attachments.md) before the publication gate.

## Publication gate

Complete this gate before each authorized PR creation or description update,
including body-only edits and motivation follow-ups. A draft-only request permits
local text, not publication. Mark drafts that have not passed this gate as unreviewed.

1. Save the complete proposed body to a file and compute its SHA-256 digest.
   Record the repository, base and head revisions, and the existing remote body for an update.
2. Dispatch a fresh, read-only `docs-analyzer` in PR-description mode.
   Give it the body file and digest, exact diff, user requirements and their sources,
   repository visibility and template, and relevant verification evidence.
   Provide the absolute path to this skill and its
   [description-review contract](references/description-review.md).
   Exclude the implementation conversation and the author's assessment of the draft.
3. Apply supported required corrections and submit the revised body for review.
   Publish only after an `approved` result matches the final body digest and both revisions.
   If the reviewer cannot compute a digest, hash its returned `reviewed_body` and compare
   that result with the file digest. An echoed input digest is not independent verification.
   If review is unavailable or incomplete, retain the draft and report the blocked write.
   Self-review is not a substitute. Do not repeat reviews merely to obtain approval.
4. Immediately before writing, compare the file digest and current revisions with the review.
   For an update, also confirm that the remote body has not changed since inspection.
   Reconcile concurrent edits before review. Any change to the candidate body or reviewed
   revisions requires another review, even when the PR head SHA stays unchanged.
5. Publish the reviewed file with `--body-file` through the authorized create or update command.
   Read the remote body back and verify it against that file before reporting success.
   Treat a terminal newline added by the hosting service as transport formatting only.

The reviewer uses this skill's content rules and the linked review contract.
It does not execute the publication gate, edit files, or dispatch another reviewer.
Description approval covers only the supplied text and evidence. It does not authorize
GitHub writes, approve the code, or bypass PR review requirements.

## Final check

- The reason comes from an allowed source.
  Otherwise, omit the section. Also omit it when the user requests this.
- Each section helps the reviewer.
- Testing contains behavior and coverage, not a command log.
- The exact body and reviewed revisions passed the publication gate before a GitHub write.
- Prose has no accidental source wrapping.
- Updating GitHub is within the user's stated authority.
