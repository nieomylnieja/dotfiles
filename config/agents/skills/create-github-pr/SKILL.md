---
name: create-github-pr
description: |
  Create a GitHub pull request when the user explicitly asks for one.
  Complete the necessary branch, commit, push, and creation steps without repeated approval.
  Use `pr-description` for the body and defer missing motivation until after creation.
allowed-tools: Bash(*scripts/get-pr-info.sh*) Bash(gh pr create*) Bash(git checkout*) Bash(git push*) Bash(git switch*)
compatibility: Requires authenticated gh CLI and git.
---

# Create a GitHub pull request

An explicit request to create a pull request authorizes the necessary branch creation,
task commits, push, and `gh pr create` within the requested scope.
Carry that authorization through supporting skills without asking the user to approve each step.
Honor explicit limits such as committed changes only or a draft pull request.

## Workflow

1. Load `pr-description`.
2. Use the requested base branch, or the remote default when none was specified.
3. Use the requested head branch, or the current task branch.
   When the task needs a new branch, choose an unused name from the task and repository conventions.
   Create it without a separate approval request.
   Never create a pull request from the base branch.
4. Commit uncommitted task changes with `git-commit` before collecting final metadata,
   unless the user explicitly excluded them.
   Preserve unrelated changes and staging. Ask only if the intended contents cannot be separated safely.
5. Run [`scripts/get-pr-info.sh`](scripts/get-pr-info.sh) on the stable branch.
   Pass the selected base with `--base`.
   Inspect the complete base-to-head diff and commit list.
6. Stop if an open pull request already exists; report its number and URL.
7. If the branch is behind or diverged, report the state.
   Do not merge, rebase, reset, or change the base without authorization.
8. Derive the title from the full diff and project title policy.
9. Draft the body with `pr-description`.
   Use the user request, linked issue, existing PR context, commits, and diff.
   Apply its missing-motivation rule without delaying creation.
10. Run current safe verification before the push.
11. Run the helper again. Require the branch, base, `HEAD`, and clean-state
    decision to match the metadata used for the title and body.
12. Write the body to a timestamped temporary file and push without force.
    Run `gh pr create --base BASE --head HEAD --title TITLE --body-file FILE`.
    Use `--draft` when the user or repository policy requires it.
    Otherwise, create a ready pull request.
13. Verify creation and report the URL, exact base and head, title, and draft state.
    Then ask the motivation follow-up defined in `pr-description`, if needed.

Resolve routine wording and metadata choices from the task and repository conventions.
Ask only when unresolved scope, destination, conflicting instructions,
or a real permission barrier prevents safe creation.
State the specific blocker and combine related questions into one request.

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
