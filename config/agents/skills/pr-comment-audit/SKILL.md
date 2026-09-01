---
name: pr-comment-audit
description: |
  Audit pull request review threads and report whether each comment is addressed.
  Resolve or reopen threads only when the user explicitly requests those state changes.
allowed-tools: Bash(*scripts/fetch-threads.sh*) Bash(*scripts/reply-to-thread.sh*) Bash(*scripts/resolve-thread.sh*) Bash(gh *)
compatibility: Requires authenticated gh CLI.
---

# Pull request comment audit

Default to report-only mode.
Review thread state and reactions are context, not proof of implementation or retraction.

## Establish evidence

1. Read the PR number, `headRefOid`, and base SHA.
2. Use a checkout whose `HEAD` equals the PR head. Do not audit unpushed working-tree changes.
3. Fetch complete paginated threads with [`scripts/fetch-threads.sh`](scripts/fetch-threads.sh).
4. Compare each actionable request with the exact PR diff and current file at the PR head.

Classify each thread as:

- `addressed`: code or documentation satisfies the request.
- `not addressed`: the requested outcome is absent.
- `rejected`: the discussion records a deliberate reason not to implement it.
- `retracted`: the original reviewer clearly withdrew it in context.
- `discussion`: no concrete code change is requested.
- `uncertain`: evidence is incomplete or conflicting.

Short replies such as `ok`, `agreed`, or a reaction do not prove retraction
without actor and conversation context.
For outdated threads, evaluate the current code.
Classify as uncertain when line movement prevents a reliable conclusion.

## Report

For every thread, include path, line, classification, and concrete evidence.
Separate already-correct thread state from proposed state changes.
Do not mention or notify a reviewer merely to report missing work.

## Optional state changes

Apply state changes only when the user explicitly requests them and after presenting the exact set:

- resolve a verified addressed or retracted thread.
- reopen only a specific thread the user selected.
- post a reply only when the user asked for one and the statement is visible at the current PR head.

Do not combine state changes with the default audit.
Report each successful mutation and preserve exact API failures.
