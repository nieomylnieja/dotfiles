---
name: create-github-pr
description: Use whenever asked to create GitHub Pull Request.
allowed-tools: Bash(*scripts/get-pr-info.sh) Bash(gh pr create*) Bash(git checkout*) Bash(git push*) Bash(git switch*)
compatibility: Requires gh CLI and git
---

# Create GitHub Pull Request

## Overview

Create GitHub Pull Requests with comprehensive analysis and interactive confirmation.
Analyzes all commits in the branch, generates the PR title,
uses the `pr-description` skill for the PR body,
and creates the PR using `gh` CLI.

## Workflow

1. Analyze branch state
2. Review all changes and commits
3. Generate PR metadata
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

**Display to user:** current branch, base branch, commit count,
list of commits, files changed, and insertions/deletions —
all from the Step 1 output.

**Critical:** Analyze ALL commits in the branch to understand the full context.
The script provides commit hashes and messages - use `git show` for detailed inspection if needed.

### Step 3: Generate PR Metadata

Based on ALL the commits and changes,
generate a concise title here
and use the `pr-description` skill to draft the body.

#### Project title policy

Before applying the default title format,
check whether the repository enforces PR title rules.
Look for title validation in project docs and automation,
especially `.github/workflows/`, `.github/actions/`, `Dangerfile`,
commitlint configuration, merge queue/merge rules,
or actions such as `semantic-pull-request`, `validate-pr-title`,
and `pull-request-title`.

If a project-specific PR title policy exists,
follow that policy exactly and mention it in the preview.
The local policy overrides the default format below.
If a title check exists but the expected format is not clear,
stop and ask for clarification instead of guessing.

#### Title format

Use this default only when no project-specific PR title policy exists.
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

Load the `pr-description` skill for the PR body.

Pass it the complete active context,
including the original user request;
all answers, corrections, and manual edits gathered during the workflow;
and the repository-derived context from Step 1 and Step 2,
such as the branch diff, commits, linked issues,
and the `pr_template` value if one exists.

Treat `pr-description` as the single source of truth
for PR body structure, content, and validation.
Do not restate or independently implement its rules here,
and do not draft or amend a body outside that skill.

Before every preview,
route the current body through `pr-description`.
This includes initial, regenerated, and manually edited bodies.
A body is ready only after `pr-description` completes its `Final Check`.
If that skill needs more context or rejects the body,
relay its question or correction and stop until the issue is resolved.

#### Draft status

Determine the draft status before showing the preview.
Honor an explicit user request for a draft or ready-for-review PR.
If the changes appear to be work in progress
and the user has not chosen a status,
offer the draft option before continuing.

Treat draft status as confirmed PR metadata,
not as an option to change after confirmation.

### Step 4: Interactive Confirmation

Present the generated PR metadata clearly to the user:

```text
Generated PR:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Title: [PR title]

Body:
[Generated by `pr-description`]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Branch: [current-branch] → [base-branch]
Commits: [N commits]
Status: [Draft | Ready for review]
```

Then ask using `AskUserQuestion`:

- **Question**: "How would you like to proceed with this pull request?"
- **Header**: "Create PR"
- **Options**:
  - "Confirm and create PR" (recommended)
  - "Regenerate title/body"
  - "Edit metadata manually"
  - "Cancel"

**Handle responses:**

- **Confirm**: Proceed to Step 5 immediately
- **Regenerate**: Go back to Step 3, generate different title/body (vary approach)
- **Edit**: Ask the user for custom title, body, and draft status;
  return the custom body to `pr-description`,
  then show the complete edited preview and ask for confirmation again
- **Cancel**: Exit gracefully, inform user no PR was created

Every path that changes displayed metadata returns to the preview.
Only confirmation of the currently displayed metadata may proceed to Step 5.

### Step 5: Push and Create PR

Push the branch if needed, then create the PR using `gh` CLI.
Use the upstream info from Step 1.

Push if needed (use `has_upstream` / `upstream_status` from Step 1 to decide), then create the PR:

```bash
git push -u origin <branch>   # new branch
# or
git push                       # existing upstream
```

Use the confirmed draft status when creating the PR:

For a ready-for-review PR:

```bash
gh pr create --title "<title>" --body "<body>"
```

For a draft PR:

```bash
gh pr create --draft --title "<title>" --body "<body>"
```

Show the PR URL with `gh pr view --json url --jq .url`.

## Best Practices

- **Analyze ALL commits**: Don't just look at latest commit, review entire branch
- **Concise title**: Under 70 characters, imperative mood
- **Delegate the body**: Use `pr-description` instead of hand-rolling PR copy here
- **Enforce the body contract**: Require the `pr-description` Final Check before preview

## Safety Protocol

- NEVER create PR from main/master branch
- NEVER force push unless explicitly requested
- NEVER create PR with uncommitted changes without warning user
- ALWAYS show user what will be in the PR before creating
- ALWAYS wait for confirmation before creating PR
- ALWAYS show and reconfirm any changed metadata
- Check for existing PRs for the current branch before creating
- NEVER preview or create a body
  that has not completed the `pr-description` Final Check

## Error Handling

### Branch Already Has PR

The script already checks for existing PRs.
If `existing_pr_number` is non-null in the Step 1 output,
inform the user and stop.

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
→ Shows "Status: Draft" in the preview
→ Creates as draft PR (--draft flag)
```
