---
name: create-github-pr
description: Use whenever asked to create GitHub Pull Request.
allowed-tools: Bash(*scripts/get-pr-info.sh) Bash(git checkout*) Bash(git diff*) Bash(git push*) Bash(gh pr create*) Bash(gh pr view*) AskUserQuestion
compatibility: Requires gh CLI and git
---

# Create GitHub Pull Request

## Overview

Create GitHub Pull Requests with comprehensive analysis and interactive confirmation.
Analyzes all commits in the branch, generates PR title and body following best practices,
and creates the PR using `gh` CLI.

## Workflow

1. Analyze branch state
2. Review all changes and commits
3. Generate PR title and body
4. Interactive confirmation (confirm/regenerate/edit/cancel)
5. Push and create PR

### Step 1: Analyze Branch State

Gather all PR information using the [helper script](scripts/get-pr-info.sh).

```bash
scripts/get-pr-info.sh
```

Read the JSON output directly from the tool result.

**Decision logic:**

- If `on_main == true`: Analyze changes, recommend branch name, create branch (see below)
- If `existing_pr_number != null`: PR already exists, show error and exit
- If `uncommitted == true`: Warn user and suggest committing first
- If `upstream_status == "behind"`: Suggest pulling first
- If `has_upstream == false`: Will need to push with -u flag

**Creating a new branch from main/master:**

1. Analyze uncommitted changes to understand what they contain
2. Generate a recommended branch name: `short-summary-with-dashes`
   - Examples: `add-user-authentication`, `fix-login-bug`, `update-docker-config`
3. Present recommendation using `AskUserQuestion`:
   - **Question**: "Create new branch from {current_branch}?"
   - **Header**: "Branch name"
   - **Options**: `["recommended-name" (Recommended)]`
   - User can select recommended name or choose "Other" to provide custom name
4. Create and checkout the branch:

```bash
git checkout -b "$branch_name"
```

### Step 2: Review All Changes

Understand the FULL scope of changes that will be in the PR.
The output from Step 1 already contains commits and stats.

```bash
git diff origin/<base_branch>...HEAD
```

**Display to user:** current branch, base branch, commit count, list of commits, files changed, insertions/deletions — all from the Step 1 output.

**Critical:** Analyze ALL commits in the branch to understand the full context.
The script provides commit hashes and messages - use `git show` for detailed inspection if needed.

### Step 3: Generate PR Title and Body

Based on ALL the commits and changes, generate a concise title and comprehensive body.

#### Title format

Follow this format: `<type>: <description>`

- Keep under 70 characters
- Prefix with change type (like `feat`)
- Use imperative mood (same as commit messages)
- Be specific but concise
- Example: "feat: add user authentication with OAuth2 support"

##### Title prefix types

| Type       | Purpose                        |
| ---------- | ------------------------------ |
| `feat`     | New feature                    |
| `fix`      | Bug fix                        |
| `docs`     | Documentation only             |
| `style`    | Formatting/style (no logic)    |
| `refactor` | Code refactor (no feature/fix) |
| `perf`     | Performance improvement        |
| `test`     | Add/update tests               |
| `build`    | Build system/dependencies      |
| `ci`       | CI/config changes              |
| `chore`    | Maintenance/misc               |
| `revert`   | Revert commit                  |

#### Body format

**Critical:** Do not add any annotations informing the PR was created by an LLM
(like "Generated with...").

**Critical:** If the `pr_template` field from Step 1 is non-null,
use it as the structure. Do not add other sections beyond what the template has.

Otherwise, provide just a simple summary section:

```markdown
## Summary
- [Bullet point 1: main change]
- [Bullet point 2: supporting change]
- [Bullet point 3: additional context]
```

**Summary section:**

- 1-3 concise bullet points
- Focus on what changed and why (not how)
- Mention any breaking changes or important notes
- Reference related issues if applicable

### Step 4: Interactive Confirmation

Present the generated PR metadata clearly to the user:

```text
Generated PR:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Title: [PR title]

Body:
## Summary
- [Summary points]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Branch: [current-branch] → [base-branch]
Commits: [N commits]
```

Then ask using `AskUserQuestion`:

- **Question**: "How would you like to proceed with this pull request?"
- **Header**: "Create PR"
- **Options**:
  - "Confirm and create PR" (recommended)
  - "Regenerate title/body"
  - "Edit title/body manually"
  - "Cancel"

**Handle responses:**

- **Confirm**: Proceed to Step 5 immediately
- **Regenerate**: Go back to Step 3, generate different title/body (vary approach)
- **Edit**: Ask user for custom title and body, then proceed to Step 5
- **Cancel**: Exit gracefully, inform user no PR was created

### Step 5: Push and Create PR

Push the branch if needed, then create the PR using `gh` CLI.
Use the upstream info from Step 1.

Push if needed (use `has_upstream` / `upstream_status` from Step 1 to decide), then create the PR:

```bash
git push -u origin <branch>   # new branch
# or
git push                       # existing upstream
```

```bash
gh pr create --title "<title>" --body "<body>"
```

Show the PR URL with `gh pr view --json url --jq .url`.

### Alternative: Create Draft PR

If changes are work-in-progress, offer to create as draft:

```bash
gh pr create --draft --title "..." --body "..."
```

## Best Practices

- **Analyze ALL commits**: Don't just look at latest commit, review entire branch
- **Concise title**: Under 70 characters, imperative mood
- **Meaningful summary**: Explain what and why, not just how

## Safety Protocol

- NEVER create PR from main/master branch
- NEVER force push unless explicitly requested
- NEVER create PR with uncommitted changes without warning user
- ALWAYS show user what will be in the PR before creating
- ALWAYS wait for confirmation before creating PR
- Check for existing PRs for the current branch before creating

## Error Handling

### Branch Already Has PR

The script already checks for existing PRs. If `existing_pr_number` is non-null in the Step 1 output, inform the user and stop.

### Uncommitted Changes

If `uncommitted == true` from Step 1, warn user:

```text
⚠️  Warning: You have uncommitted changes.
It's recommended to commit these before creating a PR.

Would you like to:
1. Commit changes first (recommended)
2. Create PR anyway (changes won't be included)
3. Cancel
```

### Not On a Branch

If detached HEAD or other issue:

```text
Error: Not on a branch. Create a branch first:
  git checkout -b feature/my-feature
```

## Usage Examples

### Simple invocation

```text
User: "create a PR" or "create pull request"

→ Checks branch state
→ Analyzes all commits
→ Generates title/body
→ Shows preview
→ Asks: Confirm/Regenerate/Edit/Cancel
→ Creates PR on confirmation
```

### With base branch specified

```text
User: "create PR to develop branch"

→ Uses 'develop' as base instead of main
→ Continues with workflow
```

### Draft PR

```text
User: "create draft PR"

→ Follows normal workflow
→ Creates as draft PR (--draft flag)
```
