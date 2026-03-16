---
name: github-post-pr-review
description: |
  Post PR review findings as a GitHub pending review via the API.
  Use after completing a PR review when the user wants to publish findings to GitHub.
  Reads the most recent review from $XDG_DATA_HOME/agents/pr-review/.
allowed-tools: Bash(gh api *) Bash(gh pr *) Bash(gh repo *) Bash(ls *) Bash(*scripts/pr-meta.sh) AskUserQuestion Write
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
REPO_SLUG=$(gh repo view --json nameWithOwner -q '.nameWithOwner' | tr '/' '-')
REVIEW_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/agents/pr-review/$REPO_SLUG"
BRANCH_SLUG=$(git rev-parse --abbrev-ref HEAD | tr '/' '-' | tr -cd '[:alnum:]-_')
REVIEW_FILE=$(ls -t "$REVIEW_DIR"/*_${BRANCH_SLUG}.json 2>/dev/null | head -1)
```

If no file is found, inform the user that no local review exists for this
branch and suggest running `review-pr` first, then stop.

Read and parse the file. Only findings with a non-null `file` and `line` can
be posted as inline comments — collect those separately. Findings without a
position will be included in the review body instead.

## Step 2 — Fetch current PR metadata

```bash
$DOTFILES/config/agents/skills/github-post-pr-review/scripts/pr-meta.sh
```

If the script exits with an error, inform the user that no PR exists and stop.

Read the JSON output directly from the tool result: `pr_number`, `commit_id`, `repo`, `review_id` (`null` when no pending review).

## Step 2b — Deduplicate against existing comments

Fetch all existing review comments (resolved and unresolved):

```bash
gh api repos/$REPO/pulls/$PR_NUMBER/comments --jq '.[] | {path, line, body}'
```

Compare each inline finding (those with `file` and `line`) against the existing
comments. A finding is a **duplicate** if an existing comment is on the same
`path` (== `file`) and the bodies describe substantially the same issue — line
numbers do not need to match exactly, as one comment may span a range while the
other targets a single line within that range.

- Remove duplicate findings from the inline comment list before posting.
- If any duplicates were found, inform the user **before posting**, listing each
  one (file, line, description). Do **not** include them in the pending review.

## Step 3 — Post the findings

- `REVIEW_ID` is not `null` → existing pending review → **3a**
- `REVIEW_ID` is `null` → no pending review → **3b**

Format each inline finding body as:
`**[{severity}]** {description}` (e.g. `**[critical]** Missing nil check`)

### 3a — Add to existing pending review

Post each inline finding individually:

```bash
gh api repos/$REPO/pulls/$PR_NUMBER/reviews/$REVIEW_ID/comments \
  --input /tmp/pr-review-comment.json \
  | jq -r '"Comment ID: \(.id)"'
```

Where `/tmp/pr-review-comment.json` is:

```json
{ "path": "<file>", "line": <line>, "side": "RIGHT", "body": "<body>" }
```

Report count added and the existing `REVIEW_ID`.

### 3b — Create a new pending review

Build the payload with all inline findings as `comments` and non-inline
findings concatenated into `body`. Omitting `event` leaves the review pending.

```bash
gh api repos/$REPO/pulls/$PR_NUMBER/reviews \
  --input /tmp/pr-review-payload.json \
  | jq -r '"Review ID: \(.id) | State: \(.state)"'
```

## Step 4 — Report

Report the Review ID and State. Remind the user the review is **pending**
and must be submitted manually on GitHub.
