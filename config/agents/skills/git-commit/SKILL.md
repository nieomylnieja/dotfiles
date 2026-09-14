---
name: git-commit
description: |
  Create a git commit when the user asks to commit changes, invokes `/commit`,
  or requests a workflow that requires task commits, such as PR creation.
  Inspect and preserve the user's staging and repository message conventions.
allowed-tools: Bash(*scripts/get-commit-info.sh*) Bash(git add *) Bash(git commit *) Bash(git diff --cached*)
---

# Git commit

An explicit commit request or an authorized workflow that requires task commits authorizes the commit.
Carry authorization from the calling workflow, including `create-github-pr`,
without a separate commit approval.
Derive the message from the task and repository conventions.
Ask only when the intended contents remain unclear.

## Workflow

1. Run [`scripts/get-commit-info.sh`](scripts/get-commit-info.sh).
2. If the index contains changes, verify that every staged change belongs to the
   approved task. If unrelated user changes are staged, leave the index unchanged
   and ask what to include.
3. If the index is empty, stage only files changed for the current task.
4. If task-owned changes cannot be separated from user changes, show the ambiguity and ask what to include.
5. Inspect the exact staged diff with `git diff --cached --`, recent commit style,
   and repository instructions. The helper keeps its JSON output bounded and
   does not embed the full patch.
6. Run the relevant verification required before the commit.
7. Create one logical commit with a concise message.
8. Inspect the created commit and report its hash and subject.

Do not use `git add -A`, `git add .`, or a broad path when unrelated changes exist.
Do not commit secrets, untracked generated artifacts,
or files outside the approved task.

## Message

Follow the repository's established convention.
If no convention exists, use:

```text
<type>: <imperative description>

[body that explains non-obvious reason or behavior]
```

Use a scope only when the repository normally uses scopes or the user requests one.
Keep the subject concise, lowercase after the prefix, and without a final period.
Use a body only when it adds information that the diff and subject do not provide.
Never add `Co-Authored-By` or other attribution unless the user asks for it.

For a multiline message, write a timestamped temporary file and use `git commit -F`.
Do not put a multiline message in shell interpolation or a heredoc.

## Authority boundary

The commit request does not authorize a push.
Push only when the user also requested it or a broader authorized workflow requires it.
