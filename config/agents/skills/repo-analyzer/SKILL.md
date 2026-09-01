---
name: repo-analyzer
description: |
  Inspect a local or remote Git repository to answer a specific codebase
  question. Use for repository URLs, external codebases, or requests to clone
  and analyze a project. Reuse a supplied local checkout first. Do not use for
  ordinary work in the current repository.
allowed-tools: Bash(*scripts/clone_repo.sh *) Bash(~/.local/share/agents/repositories/**)
---

# Repository Analyzer

Resolve one exact repository revision,
then delegate a focused read-only inspection.

## Resolve the repository

Use sources in this order:

1. A local path supplied by the user.
2. An existing checkout already identified in the conversation or workspace.
3. A remote clone when no suitable local checkout exists.

For a local checkout, resolve its root without changing it:

```sh
git -C <path> rev-parse --show-toplevel
git -C <path> rev-parse HEAD
```

Do not fetch, pull, checkout, clean, reset, or stash a user checkout.
Preserve dirty state and report the inspected commit.

## Clone a remote repository

A request to inspect a repository URL authorizes a read-only clone.
It does not authorize changes to an existing checkout.

Run the bundled helper from this skill directory:

```sh
scripts/clone_repo.sh --url <repository-url>
```

Use `--ref` when the user names a branch, tag, or commit:

```sh
scripts/clone_repo.sh --url <repository-url> --ref <revision>
```

The helper stores clones under
`${XDG_DATA_HOME:-$HOME/.local/share}/agents/repositories/`.
An existing clone is reused without network access or revision changes.

Refresh an existing managed clone only when the user explicitly asks for the
latest remote state:

```sh
scripts/clone_repo.sh --url <repository-url> --refresh --ref <revision>
```

`--refresh` requires `--ref`.
It fetches that ref and checks it out detached.
The helper refuses to change a dirty managed clone.
It never runs `git pull`.

If cloning, fetching, or revision resolution fails,
stop and report the exact Git error.
Never continue on an unverified or stale revision.

## Inspect the code

Delegate a bounded question to an available repository explorer.
Give it:

- the resolved repository root
- the exact commit hash
- the user's question
- any named files, packages, or revision scope
- a read-only instruction
- the required result format.

Ask for findings with exact `path:line` evidence.
For broad questions, split independent areas across explorers when capacity
allows.
Do not delegate repository mutations.

## Return findings

Lead with the answer to the user's question.
Include:

- the inspected source path and commit
- exact file and line evidence
- uncertainty or unverified behavior
- clone, fetch, or checkout failures
- a note when the result came from a cached clone without refresh.

Do not include a generic repository tour unless it helps answer the question.
