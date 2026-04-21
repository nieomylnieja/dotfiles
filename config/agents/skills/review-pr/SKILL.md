---
name: review-pr
description: |
  Comprehensive PR review using specialized agents.
  Use when asked to review a pull request, check code quality before merging,
  or run any subset of review aspects (code, tests, errors, types, comments, simplify).
allowed-tools: Bash(*scripts/gather-requirements.sh*) Bash(*scripts/review-meta.sh*) Bash(jira issue view*) Bash(mkdir -p */agents/pr-review/*) Edit(**/agents/pr-review/*/*.json) Write(**/agents/pr-review/*/*.json)
---

# PR Review

## Available Review Aspects

- **comments** - Analyze code comment accuracy and maintainability
- **tests** - Review test coverage quality and completeness
- **errors** - Check error handling for silent failures
- **types** - Analyze type design and invariants (if new types added)
- **code** - General code review for project guidelines
- **simplify** - Simplify code for clarity and maintainability
- **spec** - Verify implementation matches requirements (GitHub issues, Jira tickets, PR description)
- **all** - Run all applicable reviews (default)

## Workflow

1. **Checkout the PR Branch**

   Use the `git-worktrees` skill to create an isolated checkout of the PR branch:

   Pass the branch name to check out. The worktree will be created at
   `.worktrees/<branch-name>`. All subsequent steps operate from within
   that worktree path.

2. **Determine Review Scope**
   - From within the worktree, run `git diff --name-only origin/HEAD...HEAD` to identify changed files
   - Check if specific aspects were requested; default to **all**
   - Prepare the output file and capture metadata:

     ```bash
     $DOTFILES/config/agents/skills/review-pr/scripts/review-meta.sh
     ```

     Read the JSON output directly from the tool result:
     `outfile`, `repo`, `branch`, `commit_id`, `pr_number`.

3. **Gather Requirements Context**

   Run the requirements-gathering script:

   ```bash
   $DOTFILES/config/agents/skills/review-pr/scripts/gather-requirements.sh
   ```

   Read the JSON output: `source`, `issue_ref`, `requirements`.

   - If `source` is `"none"`, use `AskUserQuestion`:

     > I couldn't find linked requirements for this PR.
     > Please paste the requirements, acceptance criteria,
     > or issue description — or type `skip` to omit the spec review.

   - If `jira_attempted` is true and `source` is `"none"`,
     mention the Jira key that was tried
     and ask the user to paste the ticket description.

   Store the collected requirements text as `REQUIREMENTS`.
   If the user types `skip`, omit the spec review from the run.

4. **Determine Applicable Reviews**

   Based on changes:
   - **Always**: requirements-verifier, code-reviewer
   - **If `_test.go` or test files changed**: test-analyzer
   - **If comments/docs added or modified**: comment-analyzer
   - **If error handling changed**: silent-failure-hunter
   - **If types added/modified**: type-design-analyzer
   - **After passing review**: code-simplifier

   Skip **requirements-verifier** only if `REQUIREMENTS` is empty (user typed `skip`).

5. **Launch Review Agents**

   Default: sequential (one at a time, easier to act on).
   If user requests parallel, launch all simultaneously.

   **Requirements-verifier** — use `spec-reviewer` subagent type.
   Pass the following context in the prompt:

   - `REQUIREMENTS` text collected in step 3
   - Changed files list from `git diff --name-only origin/HEAD...HEAD`
   - Full code diff from `git diff origin/HEAD...HEAD`

6. **Aggregate Results**

   ```markdown
   # PR Review Summary

   ## Critical Issues (X found)
   - [agent]: description [file:line]

   ## Important Issues (X found)
   - [agent]: description [file:line]

   ## Suggestions (X found)
   - [agent]: suggestion [file:line]

   ## Recommended Action
   1. Fix critical issues first
   2. Address important issues
   3. Consider suggestions
   4. Re-run review after fixes
   ```

7. **Persist Results**

   Write findings to the `outfile` path from step 2 using this schema:

   ```json
   {
     "version": 1,
     "timestamp": "<ISO 8601 UTC>",
     "repo": "<owner/repo from gh repo view>",
     "branch": "<current branch>",
     "commit_id": "<HEAD sha>",
     "pr_number": <number or null>,
     "aspects": ["<aspects that were run>"],
     "findings": [
       {
         "severity": "critical | important | suggestion",
         "agent": "<agent name>",
         "file": "<relative file path or null>",
         "line": <line number or null>,
         "description": "<finding text>"
       }
     ],
   }
   ```

   Report the output path to the user.

8. **Offer to Post Review to GitHub**

   Use `AskUserQuestion` to ask:

   > Would you like to post these findings as a GitHub PR review?

   If **yes**, invoke the `github-post-pr-review` skill.

## Notes

- Agents run autonomously and return detailed reports
- Results are actionable with specific file:line references
- All agents available in `/agents` list
- Review history is stored in `$XDG_DATA_HOME/agents/pr-review/`
