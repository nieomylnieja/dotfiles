---
name: re-review-pr
description: |
  Re-review a pull request after changes were pushed.
  Compare the exact current PR head with prior findings and review-thread state,
  then persist only the findings that remain publishable.
allowed-tools: Bash(*scripts/find-review-file.sh*) Bash(*scripts/get-all-review-threads.sh*) Bash(gh api *) Bash(gh pr *) Bash(gh repo *) Edit(**/agents/pr-review/*/*.json) Write(**/agents/pr-review/*/*.json)
---

# Re-review a pull request

Reuse one verified worktree and keep the workflow read-only.

## Inputs

1. Read the current PR base and head names and SHAs.
2. Verify the worktree `HEAD` equals the current `headRefOid`.
3. Load the previous local review when available and record its `commit_id`.
4. Fetch all review threads with [`scripts/get-all-review-threads.sh`](scripts/get-all-review-threads.sh).

Do not create a second worktree when `review-pr` runs.
Pass it the verified path and exact PR metadata.

## Fresh review

Run `review-pr` without giving specialist agents the previous findings.
Use the prior aspects when they remain applicable; otherwise use all applicable read-only aspects.

Classify each previous finding from code and test evidence:

- `proved fixed`: the defect is absent and evidence exercises the fix.
- `not reproduced`: the fresh review did not report it, but no direct proof exists.
- `still present`: the defect remains.
- `intentionally rejected`: the thread records a reasoned decision not to change it.
- `regressed`: a previously resolved defect is present again.

Thread resolution is context, not proof that code is correct.
Absence from a fresh stochastic review is not proof of a fix.

## Filter current findings

For each independently verified current finding:

- keep new, still-present, orphaned, and regressed defects.
- mark a matching open thread as already tracked.
- do not suppress a present defect only because a matching thread is resolved.
- exclude an intentionally rejected suggestion unless new evidence invalidates the recorded decision.

Persist a new review JSON whose `findings` array contains only the publishable findings.
Set its `base_commit_id` and `commit_id` to the current PR base and head OIDs.
For a version-1 re-review, add this optional object:

```json
{
  "re_review": {
    "previous_review_path": "<path>",
    "previous_commit_id": "<SHA>",
    "classification_counts": {
      "proved_fixed": 0,
      "not_reproduced": 0,
      "still_present": 0,
      "intentionally_rejected": 0,
      "regressed": 0
    }
  }
}
```

Keep the main `review-pr` fields unchanged.
Never hand the unfiltered fresh-review file to a posting workflow.

## Report and publication

Report proved fixed, not reproduced, still present, rejected, regressed,
new, and already-tracked items separately.

Do not post automatically.
If the user explicitly asks to publish,
invoke `github-post-pr-review` with the exact filtered review file.
That skill must reject the file if its `commit_id` differs from the current PR head.
