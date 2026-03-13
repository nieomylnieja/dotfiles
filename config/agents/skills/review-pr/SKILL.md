---
name: review-pr
description: |
  Comprehensive PR review using specialized agents.
  Use when asked to review a pull request, check code quality before merging,
  or run any subset of review aspects (code, tests, errors, types, comments, simplify).
allowed-tools: Bash(git diff *) Bash(bash scripts/review-meta.sh) Glob Grep Read Task Skill Write
---

# PR Review

## Available Review Aspects

- **comments** - Analyze code comment accuracy and maintainability
- **tests** - Review test coverage quality and completeness
- **errors** - Check error handling for silent failures
- **types** - Analyze type design and invariants (if new types added)
- **code** - General code review for project guidelines
- **simplify** - Simplify code for clarity and maintainability
- **all** - Run all applicable reviews (default)

## Workflow

1. **Determine Review Scope**
   - Run `git diff --name-only` to identify changed files
   - Check if specific aspects were requested; default to **all**
   - Prepare the output file and capture metadata:
     ```bash
     eval "$(bash scripts/review-meta.sh)"
     ```
     This sets `OUTFILE`, `REPO`, `BRANCH`, `COMMIT_ID`, and `PR_NUMBER`.

2. **Determine Applicable Reviews**

   Based on changes:
   - **Always**: code-reviewer
   - **If `_test.go` or test files changed**: test-analyzer
   - **If comments/docs added or modified**: comment-analyzer
   - **If error handling changed**: silent-failure-hunter
   - **If types added/modified**: type-design-analyzer
   - **After passing review**: code-simplifier

3. **Launch Review Agents**

   Default: sequential (one at a time, easier to act on).
   If user requests parallel, launch all simultaneously.

4. **Aggregate Results**

   ```markdown
   # PR Review Summary

   ## Critical Issues (X found)
   - [agent]: description [file:line]

   ## Important Issues (X found)
   - [agent]: description [file:line]

   ## Suggestions (X found)
   - [agent]: suggestion [file:line]

   ## Strengths
   - What's well-done in this PR

   ## Recommended Action
   1. Fix critical issues first
   2. Address important issues
   3. Consider suggestions
   4. Re-run review after fixes
   ```

5. **Persist Results**

   Write findings to `$OUTFILE` (set in step 1) using this schema:

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
     "strengths": ["<strength text>"]
   }
   ```

   Report the output path to the user.

## Notes

- Agents run autonomously and return detailed reports
- Results are actionable with specific file:line references
- All agents available in `/agents` list
- Review history is stored in `$XDG_DATA_HOME/agents/pr-review/`
