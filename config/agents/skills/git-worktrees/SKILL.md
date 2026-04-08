---
name: git-worktrees
description: |
  Use when starting feature work that needs isolation from current workspace,
  before executing implementation plans, or when reviewing an existing branch
  (e.g. a PR) without switching away from the current branch.
  It creates isolated git worktrees under `.worktrees/`.
allowed-tools: Bash(*scripts/setup-worktree.sh*) Bash(git worktree *)
---

# Git Worktrees

## Overview

Git worktrees create isolated workspaces sharing the same repository,
allowing work on multiple branches simultaneously without switching.

**Announce at start:** "I'm using the git-worktrees skill to set up an isolated workspace."

## Directory

Always use `.worktrees/` — no other location.

## Creation Steps

### 1. Create Worktree

```bash
$DOTFILES/config/agents/skills/git-worktrees/scripts/setup-worktree.sh BRANCH_NAME
```

The script auto-detects whether the branch exists (locally or on origin):

- **Existing branch:** fetches latest from origin, creates worktree, resets to remote state.
- **New branch:** fetches the default branch (main/master), creates a new branch from it.

To branch off a specific base instead of the default branch:

```bash
$DOTFILES/config/agents/skills/git-worktrees/scripts/setup-worktree.sh --base develop BRANCH_NAME
```

The script outputs the absolute worktree path on stdout.

### 2. Run Project Setup

Auto-detect and run appropriate setup:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

### 3. Verify Clean Baseline

Run tests to ensure worktree starts clean:

```bash
# Examples - use project-appropriate command
npm test
cargo test
pytest
go test ./...
```

**If tests fail:** Report failures, ask whether to proceed or investigate.

**If tests pass:** Report ready.

### 4. Report Location

```text
Worktree ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation                  | Action                  |
|----------------------------|-------------------------|
| Tests fail during baseline | Report failures + ask   |
| No package.json/Cargo.toml | Skip dependency install |

## Common Mistakes

### Proceeding with failing tests

- **Problem:** Can't distinguish new bugs from pre-existing issues
- **Fix:** Report failures, get explicit permission to proceed

### Hardcoding setup commands

- **Problem:** Breaks on projects using different tools
- **Fix:** Auto-detect from project files (package.json, etc.)

## Example Workflow

```text
You: I'm using the git-worktrees skill to set up an isolated workspace.

[Create worktree: setup-worktree.sh feature/auth]
[Run npm install]
[Run npm test - 47 passing]

Worktree ready at /Users/jesse/myproject/.worktrees/feature/auth
Tests passing (47 tests, 0 failures)
Ready to implement auth feature
```

## Red Flags

**Never:**

- Skip baseline test verification
- Proceed with failing tests without asking

**Always:**

- Use `.worktrees/` as the worktree directory
- Auto-detect and run project setup
- Verify clean test baseline
