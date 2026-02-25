---
name: github
description: Use this skill when working with GitHub PRs, issues, and reviews.
allowed-tools: Bash(scripts/get-unresolved-comments.sh)
compatibility: Requires gh CLI to work
---

## Addressing review comments

**DO NOT resolve review threads. The user will resolve them manually.**

When addressing review feedback:

1. Address only **UNRESOLVED** comments
2. Be critical, don't just accept the feedback, but ponder upon it
3. Make the requested code changes only if they really contribute value
4. Add a reply comment explaining what was done
5. Leave the thread unresolved for the user to manually resolve

The user maintains control over comment resolution to ensure proper review workflow.

## GitHub CLI Commands

### Get Unresolved comments on Current PR

Run the [script](./scripts/get-unresolved-comments.sh) to fetch unresolved review comments for the current branch's PR:

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
