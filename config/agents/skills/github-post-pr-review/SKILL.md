---
name: github-post-pr-review
description: |
  Post PR review findings as a GitHub pending review via the API.
  Use after completing a PR review when the user wants to publish findings to GitHub.
  Reads the most recent review from $XDG_DATA_HOME/agents/pr-review/.
allowed-tools: Bash(*scripts/find-review-file.sh) Bash(*scripts/post-findings.sh*) Bash(*scripts/pr-meta.sh) Bash(gh api *) Bash(gh pr *) Bash(gh repo *) Edit(/tmp/**) Write(/tmp/**)
---

# GitHub Post PR Review

Post the review findings as a GitHub pending review.

Ask the user:

> Post these findings as a GitHub PR review? [yes/no]

If **no**, stop.

If **yes**:

## Step 1 — Load the review file

Find the most recent review for the current branch:

```bash
$DOTFILES/config/agents/skills/github-post-pr-review/scripts/find-review-file.sh
```

Read the path from the tool result as `REVIEW_FILE`.

If the script exits with an error, inform the user that no local review exists for this
branch and suggest running `review-pr` first, then stop.

Read and parse the file. Only findings with a non-null `file` and `line` can
be posted as inline comments — collect those separately. Findings without a
position will be included in the review body instead.

## Step 2 — Fetch current PR metadata

```bash
$DOTFILES/config/agents/skills/github-post-pr-review/scripts/pr-meta.sh
```

If the script exits with an error, inform the user that no PR exists and stop.

Read the JSON output directly from the tool result:
`pr_number`, `commit_id`, `repo`, `review_id` (`null` when no pending review
for the authenticated user), and `comments_file`.

Read `comments_file` with the Read tool and parse it as `EXISTING_COMMENTS`.

## Step 2b — Deduplicate against existing comments

Compare each inline finding (those with `file` and `line`) against the existing
comments. A finding is a **duplicate** if an existing comment is on the same
`path` (== `file`) and the bodies describe substantially the same issue.
Use line numbers as a heuristic: exact line matches are strong duplicates,
and nearby shifted lines can still be duplicates after rebases.

- Remove duplicate findings from the inline comment list before posting.
- If any duplicates were found, inform the user **before posting**, listing each
  one (file, line, description).
  Do **not** include them in the pending review.

## Step 3 — Post the findings

After deduplication in step 2b,
write the final findings to temporary JSON files under `/tmp/`:

- Use timestamped names (UTC) such as `github-post-pr-review-<timestamp>-*.json`
  where timestamp format is `YYYYMMDDTHHMMSSZ`.

- `INLINE_FINDINGS_FILE`: array of findings with `file` and `line`
- `NON_INLINE_FINDINGS_FILE`: array of findings without a position

Run the posting script:

```bash
$DOTFILES/config/agents/skills/github-post-pr-review/scripts/post-findings.sh \
  --repo "$REPO" \
  --pr-number "$PR_NUMBER" \
  --commit-id "$COMMIT_ID" \
  --review-id "$REVIEW_ID" \
  --inline-findings "$INLINE_FINDINGS_FILE" \
  --non-inline-findings "$NON_INLINE_FINDINGS_FILE"
```

Read the JSON result directly from the tool output.
The script returns:

- `mode`: `new`, `updated_existing_pending`, `blocked_existing_pending`, or `nothing_to_post`
- `review_id`
- `state`
- `inline_comments_posted`
- `non_inline_findings_included`
- `non_inline_findings_skipped`

## Step 4 — Report

Report `review_id`, `state`, and how many findings were posted.
If `mode` is `blocked_existing_pending`, explicitly tell the user that an
older pending review already exists and must be submitted or deleted before
posting new findings. This includes pending reviews not created by this skill.
If `mode` is `updated_existing_pending`, explicitly tell the user that
non-inline findings were added to the pending review body and inline findings
were skipped when present. This mode only applies to pending reviews created
by this skill.
If `mode` is `nothing_to_post`, report that all findings were removed during
deduplication and nothing was posted.
Remind the user the review is **pending** and must be submitted manually on GitHub.

## What not to do

Never remove pending reviews, even if you experience problems posting your own findings.
