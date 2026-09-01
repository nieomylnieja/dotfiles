---
name: create-github-pr
description: |
  Create a GitHub pull request when the user explicitly asks for one.
  Preserve the requested base, use `pr-description` for the body, and avoid duplicate confirmation.
allowed-tools: Bash(*scripts/get-pr-info.sh*) Bash(gh pr create*) Bash(git checkout*) Bash(git push*) Bash(git switch*)
compatibility: Requires authenticated gh CLI and git.
---

# Create a GitHub pull request

An explicit request to create a pull request authorizes the required push
and `gh pr create` for the selected branch.
Ask only when a missing choice can change the result.

## Workflow

1. Load `pr-description`.
2. Determine the requested base branch.
3. If the current branch is the base branch, ask for a branch name before switching.
   Never create a pull request from the base branch.
4. Resolve uncommitted task changes before collecting final metadata.
   Invoke `git-commit` only when the user also authorized a commit.
   Otherwise ask whether to commit the task changes or leave them out.
5. Run [`scripts/get-pr-info.sh`](scripts/get-pr-info.sh) on the stable branch.
   Pass the requested base with `--base`; otherwise use the remote default.
   Inspect the complete base-to-head diff and commit list.
6. Stop if an open pull request already exists; report its number and URL.
7. If the branch is behind or diverged, report the state.
   Do not merge, rebase, reset, or change the base without authorization.
8. Derive the title from the full diff and project title policy.
9. Draft the body with `pr-description`.
   Use the user request, linked issue, existing PR context, commits, and diff.
10. Run current safe verification before the push.
11. Run the helper again. Require the branch, base, `HEAD`, and clean-state
    decision to match the metadata used for the title and body.
12. Write the body to a timestamped temporary file and push without force.
    Run `gh pr create --base BASE --head HEAD --body-file FILE`.
13. Report the URL, exact base and head, title, and draft state.

If title, body, base, head, or draft state is ambiguous,
show the proposed value and ask one focused question.
Do not request another generic confirmation after the user has already authorized PR creation.

## Title

Follow a repository-enforced title policy when present.
If no policy exists, use `<type>: <imperative description>` and keep it under 70 characters.
Do not infer a project policy from unrelated commit messages alone.

## Body

`pr-description` is the source of truth for structure, motivation,
testing evidence, and GitHub line formatting.
Do not substitute the repository template unless the user explicitly selects it for this task.

## Safety

- Preserve the exact user-selected base and head.
- Never force-push.
- Never include uncommitted working-tree changes in the claimed PR content.
- Do not create a second open pull request for a branch that already has one.
- Do not leak private issue or repository context into a public repository.
- Treat push and PR creation failures as failures; report their exact output.
