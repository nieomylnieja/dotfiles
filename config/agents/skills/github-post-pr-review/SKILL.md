---
name: github-post-pr-review
description: |
  Publish an already completed, verified review as a pending GitHub review when the user explicitly asks to post it.
  Accept an exact review file and reject stale PR-head metadata.
allowed-tools: Bash(*scripts/find-review-file.sh*) Bash(*scripts/post-findings.sh*) Bash(*scripts/pr-meta.sh*) Bash(gh api *) Bash(gh pr *) Bash(gh repo *) Edit(/tmp/**) Write(/tmp/**)
compatibility: Requires authenticated gh CLI.
---

# Post a GitHub pull request review

This workflow writes to GitHub and can notify people.
Use it only after explicit publication authority.
Do not request another generic confirmation when the caller already obtained that authority.

## Preflight

1. Use the exact review file supplied by the caller. If none was supplied, use
   [`scripts/find-review-file.sh`](scripts/find-review-file.sh). Pass
   `--branch` when the current checkout is detached or differs from the PR head.
2. Parse the file and require valid review schema, repository identity, PR number,
   `base_commit_id`, and `commit_id`.
3. Run [`scripts/pr-meta.sh`](scripts/pr-meta.sh).
4. Require the review repository and PR number to match the target.
5. Require review `base_commit_id` and `commit_id` to equal the current PR base
   and head OIDs. Stop when either side of the reviewed diff is stale.
6. Compare findings with all existing review comments.
   Build a fingerprint from the repository-relative path, current RIGHT-side
   line, and description. Remove a leading `./` from the path, use `/`
   separators, preserve path case, trim the description, collapse its internal
   whitespace, and remove one rendered `**[severity]**` prefix from an existing
   comment. Ignore severity so a relabel does not repost the same defect.
   Do not use fuzzy wording as proof; manually suppress a differently worded
   comment only after confirming that it describes the same defect.
7. Remove only confirmed duplicates and report them.

An inline comment needs a location on the current PR diff.
Preflight every candidate location.
Move a valid finding with no current diff position into the review body.
Do not let one invalid position fail the whole batch.

## Post

Write the final inline and body findings to timestamped temporary JSON files.
Run [`scripts/post-findings.sh`](scripts/post-findings.sh) with the exact repository,
PR number, base and head commits, pending review ID, and those files.

Never delete, submit, or replace another pending review.
If an incompatible pending review exists, stop and report its ID.
Leave the created review pending so the user can inspect and submit it on GitHub.

## Report

Report the review ID, state, target PR head, posted inline count,
body count, duplicates removed, and relocated findings.
Preserve exact API failures.
