---
name: pr-comment-audit
description: |
  Audit PR review threads to ensure all reviewer comments are properly addressed.
  Use this skill when the user wants to verify PR comments are handled, audit review
  threads, check if suggestions were applied, resolve/unresolve threads based on code
  changes, or ensure nothing was missed before merging. Also trigger when the user says
  things like "check the PR comments", "are all comments addressed", "audit the review",
  "resolve handled comments", or "close out review threads".
allowed-tools: Bash(*scripts/fetch-threads.sh) Bash(*scripts/reply-to-thread.sh) Bash(*scripts/resolve-thread.sh) Bash(gh *)
compatibility: Requires gh CLI authenticated with repo scope
---

# PR Comment Audit

Audit all review threads on a PR, verify each suggestion against the actual code
changes, and update thread resolution status accordingly.

## Workflow

### Step 0 — Ensure local code matches the PR branch

The audit reads local files to verify suggestions, so the working tree must match
the PR's head branch.

1. Determine the PR's head branch:
   - If a PR number was given: `gh pr view NUMBER --json headRefName --jq .headRefName`
   - Otherwise: use the current branch as the PR branch

2. Compare against the current branch: `git branch --show-current`

3. If they differ, use the `git-worktrees` skill to create an isolated worktree
   for the PR branch.
   The skill should output the worktree path. Set `WORK_DIR` to that path.

4. If already on the correct branch, set `WORK_DIR` to the repo root (`.`).

All file reads in later steps use `WORK_DIR` as the base path — e.g.,
`WORK_DIR/path/from/thread`.

### Step 1 — Fetch all review threads

Run the fetch script to get every thread with its full comment chain:

```bash
$DOTFILES/config/agents/skills/pr-comment-audit/scripts/fetch-threads.sh
```

Pass `--pr NUMBER` if the user specified a PR number. Otherwise, auto-detects
from the current branch.

Parse the JSON output. Each thread has: `id`, `path`, `line`, `isResolved`,
`isOutdated`, `resolvedBy`, and `comments[]` (with `author`, `body`, `createdAt`).

### Step 2 — Classify each thread

For each thread, read the full comment chain and classify it into one of these
categories:

#### 2a. Reviewer retracted

The reviewer (first comment's author) later posted a reply indicating the
suggestion is not needed. Look for signals like:

- "nvm", "never mind", "fair point", "makes sense", "ok", "agreed"
- "not needed", "disregard", "scratch that", "you're right"
- Thumbs-up reactions or short affirmative replies from the same author

If the reviewer retracted → **resolve** the thread (if not already resolved).
No further analysis needed.

#### 2b. Suggestion requires code changes

The comment requests a specific code change (refactor, bug fix, naming,
logic change, etc.). Proceed to Step 3 for these.

#### 2c. Discussion / question / FYI

The comment is informational, asks a question, or is general discussion without
a concrete actionable suggestion. These do not require code changes.

If there's a satisfactory reply already in the thread → **resolve**.
If the question is unanswered → leave unresolved, skip (do not reply).

### Step 3 — Verify code changes against suggestions

For each thread classified as 2b:

1. Read the file at `WORK_DIR/<path>` where `<path>` is the thread's `path` field
   (`WORK_DIR` was set in Step 0)
2. Read the PR diff for that file: `gh pr diff --name-only` to confirm the file
   was changed, then `gh pr diff` filtered to that path
3. Determine whether the suggestion was implemented — look at:
   - The specific lines mentioned in the review comment
   - The surrounding context in the current file
   - The diff to see what changed

A suggestion is **addressed** when the code change meaningfully satisfies what
the reviewer asked for. It does not need to be a verbatim copy of a suggestion
block — the intent matters more than the exact implementation.

### Step 4 — Take action

Present findings to the user before making any changes. Group threads by status:

```markdown
Addressed (will resolve):
  - path/to/file.go:42 — reviewer asked for X, diff shows Y (addresses it)

Not addressed (will unresolve + tag reviewer):
  - path/to/file.go:88 — reviewer asked for Z, not found in changes

Retracted by reviewer (will resolve):
  - path/to/other.go:15 — reviewer said "nvm"

Already correct:
  - path/to/file.go:20 — already resolved, suggestion applied
```

Ask the user:

> Proceed with these resolution changes? [yes/no]

If **no**, stop and let the user adjust.

If **yes**, for each thread:

#### Addressed → Resolve

If not already resolved:

```bash
$DOTFILES/config/agents/skills/pr-comment-audit/scripts/resolve-thread.sh \
  --resolve --id THREAD_ID
```

#### Not addressed → Unresolve + notify

If the thread is resolved but the suggestion was not actually applied, unresolve it:

```bash
$DOTFILES/config/agents/skills/pr-comment-audit/scripts/resolve-thread.sh \
  --unresolve --id THREAD_ID
```

Then reply tagging the original reviewer with what's still missing:

```bash
$DOTFILES/config/agents/skills/pr-comment-audit/scripts/reply-to-thread.sh \
  --id THREAD_ID \
  --body "@REVIEWER_LOGIN This suggestion hasn't been addressed yet: <concise description of what's missing and why the current code doesn't satisfy the request>"
```

Keep the reply factual and specific. Reference the exact code or diff lines.
Be professional and not vague.

#### Retracted → Resolve

Same as "Addressed" — resolve silently, no reply needed.

### Step 5 — Summary

After all actions complete, print a summary:

```markdown
PR #123 comment audit complete:
  Resolved: 5 threads
  Unresolve + notified: 2 threads
  Skipped (already correct): 3 threads
  Skipped (unanswered questions): 1 thread
```

## Edge cases

- **Outdated threads** (`isOutdated: true`): The code around the comment has
  changed significantly. Still check the current file — the suggestion may have
  been addressed by the refactor even if the line numbers shifted. If you cannot
  determine whether it was addressed, leave it unresolved and skip.

- **Multi-suggestion threads**: A single thread may contain multiple suggestions
  from back-and-forth discussion. Consider the latest actionable suggestion as
  the one to verify.

- **Self-reviews**: If the PR author commented on their own PR, treat these as
  TODO notes. Check if the author addressed their own note in code.

- **Bot comments**: Skip threads where the first comment author looks like a bot
  (e.g., contains `[bot]` or `github-actions`).
