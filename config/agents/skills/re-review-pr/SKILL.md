---
name: re-review-pr
description: |
  Re-review a pull request after changes were pushed.
  Compare the exact current PR head with prior findings and review-thread state,
  then persist only the findings that remain publishable.
allowed-tools: Bash(*scripts/find-review-file.sh*) Bash(*scripts/get-all-review-threads.sh*) Bash(gh api *) Bash(gh pr *) Bash(gh repo *) Edit(**/agents/pr-review/*/*.json) Write(**/agents/pr-review/*/*.json)
---

# Re-review a pull request

Use the `review-pr` handoff and coordinator for the fresh review and final comparison.
If you are already the coordinator, complete the independent review before reading
[the comparison workflow](references/comparison.md). Do not dispatch another coordinator.

## Prepare comparison context

1. Read the current PR base and head names and SHAs.
2. Reuse an existing worktree only after verifying its `HEAD` equals the current `headRefOid`.
   Let `review-pr` prepare the exact worktree when no matching checkout exists.
3. Locate the previous local review when available and record its path and `commit_id`.
4. Fetch all review threads with [`scripts/get-all-review-threads.sh`](scripts/get-all-review-threads.sh).

Run `review-pr` with this metadata, any verified worktree path, and a re-review handoff.
Include the absolute path to the comparison reference and accessible prior review/thread data.
Keep source-access errors explicit. Missing history limits comparison without blocking the
fresh review. Request one final filtered report from the coordinator.

The coordinator recomputes applicable aspects for the current head, including newly changed
boundaries. Preserve explicit user restrictions; a prior automatic selection is not a restriction.
Normalize legacy `comments` to `docs`. Initial specialists receive neither previous findings nor
prior verdicts. The coordinator compares history only after the independent investigation.

## Deliver

The main session verifies the current target and persists the coordinator's filtered report
through `review-pr`. Keep its coverage, checks, limitations, reasoning selection, and adversarial
record. Never hand an intermediate unfiltered review to a posting workflow.

Report proved fixed, not reproduced, still present, rejected, regressed, new, and already-tracked
items separately. Publish only when explicitly requested, using `github-post-pr-review` with the
exact filtered file. That skill must reject a file whose `commit_id` differs from the current PR head.
