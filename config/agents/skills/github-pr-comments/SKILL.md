---
name: github
description: Use this skill when addressing GitHub PR comments.
allowed-tools: Bash(*scripts/get-unresolved-comments.sh)
compatibility: Requires gh CLI to work
---

# Addressing review comments

**DO NOT resolve review threads. The user will resolve them manually.**

## Commit gate

Do not post a PR reply for changes that exist only in the working tree.
Before replying, verify that the relevant changes are committed and that the
commit is visible on the PR branch. A reply must describe code the reviewer can
actually inspect in the PR.

If the changes are not committed and pushed, or the user has not authorized
those actions, stop after implementing and verifying the changes. Report the
local state to the user, but do not add a GitHub reply.

When addressing review feedback:

1. Address only **UNRESOLVED** comments
2. Be critical, don't just accept the feedback, but ponder upon it
3. Make the requested code changes only if they really contribute value
4. After the commit gate passes, add a reply comment explaining what was done
5. Leave the thread unresolved for the user to manually resolve

The user maintains control over comment resolution to ensure proper review workflow.

## GitHub CLI Commands

### Get Unresolved comments on Current PR

Run the [script](./scripts/get-unresolved-comments.sh) to fetch unresolved
review comments for the current branch's PR:

This script automatically:

- Detects the current repo and branch
- Finds the associated PR
- Fetches only unresolved review comments via GraphQL
- Returns JSON with path, line, body, and outdated status

### Other Useful Commands

#### Get All Review Comments (Resolved and Unresolved)

```bash
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments --jq '.[] | {path, line, body}'
```

#### View PR Details

```bash
gh pr view PR_NUMBER --json title,body,comments,reviews
```
