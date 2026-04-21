---
name: git-commit
description: |
  Execute git commit with interactive confirmation.
  Use when user asks to commit changes, create a git commit, or mentions "/commit".
allowed-tools: Bash(*scripts/get-commit-info.sh) Bash(git add *) Bash(git commit *)
---

# Git commit

## Overview

Create standardized, semantic git commits using simplified
Conventional Commits specification (for instance, no scope).
Analyze the actual diff to determine appropriate type and message.

**IMPORTANT**: Do not determine and use `scope`,
remember this is a simplified version of Conventional Commits.

```text
<type>: <description>

[optional body]
```

### Commit Types

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

### Message

Analyze the diff to determine:

- **Type**: What kind of change is this?
- **Description**: One-line summary (present tense, imperative, <72 chars).
  Do not capitalize the first letter and do not end with a period.
- **Body** (optional): Detailed explanation if changes are complex

**CRITICAL**: NEVER add `Co-Authored-By` footers.
User does not want attribution footers.

### Example

Input:

```diff
diff --git a/src/user.js b/src/user.js
index abc123f..def456g 100644
--- a/src/user.js
+++ b/src/user.js
@@ -10,7 +10,7 @@
 const getUser = (id) => {
   // Fetch user from database
   // ...
-  return { id, name: 'Old Name' };
+  return { id, name: 'New User' };
 };

 const saveUser = (user) => {
@@ -25,4 +25,8 @@
   // ...
 };

-module.exports = { getUser, saveUser };
+const deleteUser = (id) => {
+  // Delete user from database
+};
+
+module.exports = { getUser, saveUser, deleteUser };
```

Expected output:

```text
feat(user): add delete user function

Adds a new function `deleteUser` to handle the removal of users from the database.
Also updates the export to include the new function.
```

## Workflow

1. Check staged files
2. Show changes
3. Generate message
4. Interactive confirmation (confirm/regenerate/edit/cancel)
5. Commit

### Step 1: Analyze current state

Gather all commit information using the [helper script](scripts/get-commit-info.sh).

```bash
scripts/get-commit-info.sh
```

Read the JSON output directly from the tool result.

**Decision logic:**

- If **staged files exist** (`has_staged == true`): Use them (user explicitly staged what they want)
- If **no staged files but unstaged exist** (`has_unstaged == true`): Offer to stage them or cancel
- If **nothing to commit** (`nothing_to_commit == true`): Inform user and exit

### Step 2: Show what files will be committed

The `commit_info` from Step 1 already contains all the data needed.

Use `staged_files` and `staged_stat` from the Step 1 tool output.

**Display to user:**

- Clear list of files (from `staged_files`)
- Change statistics (from `staged_stat`)
- File status (modified, added, deleted)
- Brief summary of what changed

### Step 3: Generate Commit Message

Analyze the diff to determine:

- **Type**: What kind of change is this?
- **Description**: One-line summary (present tense, imperative, <72 chars)
- **Body** (optional): Detailed explanation if changes are complex

**CRITICAL**: NEVER add `Co-Authored-By` footers.
User does not want attribution footers.

### Step 4: Interactive Confirmation

Present the generated commit message clearly to the user:

```text
Generated commit message:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<type>: <description>

[optional body]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then ask using `AskUserQuestion`:

- **Question**: "How would you like to proceed with this commit?"
- **Header**: "Commit"
- **Options**:
  - "Confirm and commit" (recommended)
  - "Regenerate message"
  - "Edit message manually"
  - "Cancel"

**Handle responses:**

- **Confirm**: Proceed to Step 5 immediately
- **Regenerate**: Go back to Step 3, generate a different message (vary the approach/style)
- **Edit**: Prompt user for manual message text, then proceed to Step 5
- **Cancel**: Exit gracefully, inform user no commit was made

### Step 5: Execute Commit

**CRITICAL**: Never use `$()` or heredoc for commit messages.

- **Single-line message**: use `-m` directly
  ```bash
  git commit -m "<type>: <description>"
  ```
- **Multi-line message**: write to `/tmp/git-commit-msg-<timestamp>` with the `Write` tool
  (use a unique name like `/tmp/git-commit-msg-20260316-143052` to avoid collisions), then:
  ```bash
  git commit -F /tmp/git-commit-msg-<timestamp>
  ```

**Post-commit feedback:**

```bash
# Show the commit that was just created
git log -1 --format="%C(green)✓%C(reset) Committed: %h - %s"

# Show short summary
git show --stat --oneline HEAD
```

**Optional**: If on a feature branch (non-main), ask: "Push to remote?"

## Best Practices

- One logical change per commit (if possible and you're coding)
- Present tense: "add" not "added"
- Imperative mood: "fix bug" not "fixes bug"
- Reference issues: `Closes #123`, `Refs #456`
- Keep description under 72 characters
- **NEVER add Co-Authored-By footers** - user explicitly does not want them
- **NEVER use heredoc or `$()`** for commit messages — single-line: `-m`; multi-line: `Write` to `/tmp/git-commit-msg-<timestamp>` + `git commit -F`

## Intelligent Automation

### Smart State Detection

The skill automatically handles different repository states:

**Staged files exist** → Analyze and commit them
**No staged files** → Prompt user to stage changes first or offer to help stage files
**Nothing to commit** → Inform user and suggest `git add`

### Context-Aware Message Generation

When generating commit messages, use the pre-fetched data from Step 1:

- **Recent commits**: Use `recent_commits` field for style patterns (no extra `git log` needed)
- **Branch name**: Use `issue_number` field — already extracted from `current_branch`
- **Diff content**: Use `staged_diff` field to understand if it's a feature, fix, refactor, etc.

### Issue Reference Detection

The `issue_number` field from Step 1 already contains the extracted issue/ticket number (or `null`).
Supports numeric (`#123`) and JIRA-style (`PROJ-789`) references from branch names.

If `issue_number != null`, suggest including it in the commit footer (user can accept/decline in edit step).

## Git Safety Protocol

- NEVER update git config
- NEVER run destructive commands (--force, hard reset) without explicit request
- NEVER force push to main/master
- NEVER add Co-Authored-By footers (user explicitly prohibits this)
- NEVER commit secrets (.env, credentials.json, private keys)
- ALWAYS show user what will be committed before doing it
- ALWAYS wait for confirmation before executing commit

## Usage Examples

### Simple invocation

```text
User: "commit" or "/commit"

→ Checks git status
→ Shows staged files (if any)
→ Generates conventional commit message
→ Asks: Confirm/Regenerate/Edit/Cancel
→ Commits on confirmation
```

### With staged files

```text
User: (has already run `git add ...`)
User: "commit"

→ Detects staged files
→ Shows: "3 files staged: src/auth/login.ts, ..."
→ Generates: "feat(auth): add password reset flow"
→ User confirms → Commits
```

### No staged files

```text
User: "commit"

→ Detects no staged files
→ Shows: "No files staged. Modified files: src/api/users.ts, ..."
→ Asks: "Stage all modified files?" or "Cancel and let me stage manually"
→ If user stages → Continue with workflow
```

### Regenerate message

```text
User: "commit"
→ Shows message: "chore: update dependencies"
→ User selects: "Regenerate message"
→ Generates different approach: "build: upgrade project dependencies"
→ User confirms → Commits
```

### Edit message

```text
User: "commit"
→ Shows message: "feat: add user profile"
→ User selects: "Edit message manually"
→ User provides: "feat(profile): add user avatar upload"
→ Commits with edited message
```
