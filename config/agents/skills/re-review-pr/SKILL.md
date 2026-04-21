---
name: re-review-pr
description: |
  Re-review a PR after fixes have been pushed. Use for a second pass, follow-up
  review, re-check after addressing comments, or any time you want to look again
  at a PR that was previously reviewed. Checks which reported issues have been
  addressed, runs a fresh unbiased review, and filters out noise from already-tracked
  or already-resolved GitHub threads. Trigger on: "re-review", "second pass",
  "review again", "check if issues were fixed", "follow-up review", "look again after fixes".
allowed-tools: Bash(*scripts/find-review-file.sh*) Bash(*scripts/get-all-review-threads.sh*) Bash(gh api *) Bash(gh pr *) Bash(gh repo *) Edit(**/agents/pr-review/*/*.json) Write(**/agents/pr-review/*/*.json)
---

# Re-Review PR

Re-review a PR after fixes have been pushed. The goal is a clean, unbiased signal:
what is genuinely new or still unresolved — not noise from already-tracked issues.

## Step 0 — Set Up Worktree

Determine the PR branch to review. If the user specified a PR number or branch,
use that; otherwise assume the current branch.

```bash
# Get the branch name for the target PR
gh pr view <PR_NUMBER_OR_CURRENT> --json headRefName -q '.headRefName'
```

Invoke the `git-worktrees` skill to create an isolated worktree for that branch.
All subsequent steps operate inside the worktree directory.

Skip the project setup and baseline test verification steps from the
git-worktrees skill — they are not needed for a review-only workflow.

## Step 1 — Load Previous Review

Find the most recent local review file for the current branch:

```bash
$DOTFILES/config/agents/skills/github-post-pr-review/scripts/find-review-file.sh
```

Read the path as `PREV_REVIEW_FILE`. If the script exits with an error, note that
no previous local review exists and proceed without it (skip filtering steps that
depend on it).

Parse the file to extract: `findings` (list) and `aspects` (list of review aspects run).

## Step 2 — Fetch GitHub Thread State

Run (without any flags or arguments):

```bash
$DOTFILES/config/agents/skills/re-review-pr/scripts/get-all-review-threads.sh
```

This returns one JSON object per review thread with fields:
`path`, `line`, `body`, `author`, `isResolved`, `isOutdated`, `comments` (array of `{author, body}` for all replies).

Partition threads into:

- **resolved_threads** — `isResolved == true`
- **open_threads** — `isResolved == false`

## Step 3 — Run Fresh Review

Invoke the `review-pr` skill for a full, unbiased review using the same aspects
that were run previously (from `aspects` in the previous review file). If no
previous review exists, use **all** aspects.

Do not mention the previous review findings to the review agents — the fresh
review must be unbiased.

After the skill completes, load its output file (the most recent one just written)
using `find-review-file.sh` again — it will now point to the file just created.
Read it as `FRESH_REVIEW`.

## Step 4 — Classify Previous Findings

With both the fresh review and the GitHub thread state in hand, classify each
finding from the previous review:

**Deliberately rejected** — there is a **resolved** GitHub thread that substantially
matches the finding, but reading its `comments` array reveals that the author
(or a reviewer) consciously decided not to implement the suggestion. Signs of
deliberate rejection include phrases like "won't fix", "out of scope", "decided
not to", "not applicable", "disagree", "intentionally", or any reply where the
author explains why the suggestion was declined rather than accepted. Treat these
as **suppressed** (do not re-raise in the fresh review), but list them separately
in the report as "Intentionally not addressed".

**Addressed** — any of these is true:

- There is a **resolved** GitHub thread on the same file whose body substantially
  describes the same issue (semantic match, not exact string) and no comment
  signals a deliberate rejection (see above).
- There is **no** matching GitHub thread **and** the finding does not appear in
  the fresh review — it was silently fixed without a thread being posted.

**Still open** — an **unresolved** GitHub thread substantially matches it.

**Orphaned** — no GitHub thread exists and the issue still appears in the fresh
review. This means it was never posted to GitHub and hasn't been fixed. Treat
these as still-relevant findings and include them in the "New Findings" section
of the report (they will surface naturally since they're also in the fresh review).

Build three lists from the above: `addressed_findings`, `still_open_findings`,
and `rejected_findings`.

## Step 5 — Filter Fresh Findings

For each finding in `FRESH_REVIEW`, decide whether to **suppress** it:

1. **Suppress** if there is a matching **unresolved** GitHub thread (already
   tracked — no value in re-reporting).
2. **Suppress** if there is a matching **resolved** GitHub thread (already fixed
   and reviewed — noise).
3. **Keep** everything else, including orphaned previous findings that still appear.

A match is semantic (same file + similar described issue), not an exact string
comparison.

> **Note:** When posting to GitHub via `github-post-pr-review` in Step 6, that
> skill reads the unfiltered fresh review file. Its own deduplication catches
> findings matching open threads, but will not catch findings matching resolved
> threads. Suppressed findings of the second kind may still be posted if you
> proceed to Step 6 — inform the user of this if any such findings were suppressed.

## Step 6 — Report

Present a consolidated report:

```markdown
# Re-Review Summary

## Previously Reported — Now Addressed (X)
- [file:line] description

## Previously Reported — Intentionally Not Addressed (X)
- [file:line] description (reason from thread)

## Previously Reported — Still Open (X)
- [file:line] description

## New Findings (X)

### Critical (X)
- [agent]: description [file:line]

### Important (X)
- [agent]: description [file:line]

### Suggestions (X)
- [agent]: suggestion [file:line]

## Suppressed (X already tracked on GitHub)
- brief note of what was filtered

## Recommended Action
...
```

## Step 7 — Offer to Post

Ask the user:

> Would you like to post the new findings as a GitHub PR review?

If **yes**, invoke the `github-post-pr-review` skill. If any findings were
suppressed due to matching resolved GitHub threads (issue #2 in Step 5), warn
the user that those may still be included in the posted review, and suggest
they review the pending review on GitHub before submitting it.
