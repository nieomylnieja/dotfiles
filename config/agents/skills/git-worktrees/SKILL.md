---
name: git-worktrees
description: |
  Use when approved feature work needs isolation, or when reviewing a branch without switching the current checkout.
  Create or reuse a verified checkout under `.worktrees/` without resetting existing work.
allowed-tools: Bash(*scripts/worktree-setup.sh*) Bash(git worktree *)
---

# Git worktrees

Announce that the task will use an isolated worktree.
Honor a user-supplied worktree path instead of creating another checkout.

## Setup

Choose a plain, descriptive `BRANCH` name with no slash (`/`). Use one path
segment, such as `fix-login-timeout`, not a categorized name such as
`feat/login-timeout`. The branch name also becomes the directory name directly
under `.worktrees/`.

Run the helper from the repository root:

```sh
$DOTFILES/config/agents/skills/git-worktrees/scripts/worktree-setup.sh BRANCH
```

Use `--base BRANCH` only when creating a new branch from a non-default base.
Use `--commit COMMIT LABEL` for an exact detached review checkout after the
object is available locally. `LABEL` names the path under `.worktrees/`; include
the pull request number and a short commit ID so a later head does not collide
with an older review checkout. Use one path segment with no slash for `LABEL`.
Do not copy ignored or untracked hidden files into a worktree. If the task needs
local configuration, ask for the exact non-secret source and destination as a
separate operation.

The helper must not reset, clean, rebase, merge, or overwrite an existing checkout.
If an existing worktree is dirty, keep it unchanged and report the state.

## Verify identity

Before any task edit, verify and report:

- repository root and worktree path;
- checked-out branch;
- `HEAD` commit;
- expected remote or base commit;
- working-tree status.

For a pull request review, compare the checkout `HEAD` with the PR `headRefOid`.
Do not review local unpushed changes as if reviewers can see them.

## Project setup

Inspect repository instructions for setup and baseline checks.
Do not run package installation, module download, build, activation, or network-fetching commands automatically.
Run a safe baseline check when it is useful and already supported by the environment.
Report failures and let the calling workflow decide whether the baseline blocks the task.
