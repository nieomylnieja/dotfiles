---
name: github-pr-comments
description: |
  Address unresolved GitHub pull request review comments.
  Verify feedback, implement supported changes, and write replies or resolve threads only when explicitly requested.
allowed-tools: Bash(*scripts/get-unresolved-comments.sh*)
compatibility: Requires authenticated gh CLI.
---

# Address pull request comments

Load `feedback-reception` before evaluating comments.
Default to address-only mode: inspect and implement, but do not reply or resolve threads.

## Workflow

1. Identify the PR and record its `headRefOid`.
2. Verify the checkout path, branch, and `HEAD` against that PR head.
3. Fetch all unresolved threads with [`scripts/get-unresolved-comments.sh`](scripts/get-unresolved-comments.sh).
4. Read each full thread, including author, replies, reactions, outdated state, and thread ID.
5. Classify the feedback through `feedback-reception`.
6. Implement only supported, in-scope changes and run relevant checks.
7. Report addressed, rejected, outdated, discussion-only, and blocked threads.

## GitHub writes

A local edit does not authorize a reply or resolution.
Before any write, require both:

- explicit user intent to reply or resolve; and
- a commit visible at the current PR head that contains the relevant change.

Reply with a concise description of what reviewers can inspect.
Resolve only threads verified as addressed or explicitly retracted.
Do not resolve an unclear, rejected, or discussion-only thread merely to reduce the open count.
