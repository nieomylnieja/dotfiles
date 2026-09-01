---
name: review-pr
description: |
  Run a read-only pull request review with independent specialist agents.
  Use when asked to review a PR, assess merge risk, or review selected code, test,
  error-handling, type, documentation, comment, or specification aspects.
allowed-tools: Bash(*scripts/gather-requirements.sh*) Bash(*scripts/review-meta.sh*) Bash(jira issue view*) Bash(mkdir -p */agents/pr-review/*) Edit(**/agents/pr-review/*/*.json) Write(**/agents/pr-review/*/*.json)
---

# Pull request review

Review the exact pull request head against its actual base.
Here, read-only means no repository-content edits or GitHub writes.
Fetching missing Git objects and creating the isolated review worktree are
authorized setup operations. Review requests do not authorize thread changes
or GitHub review posts.

## Establish scope

1. Read PR metadata: number, `baseRefName`, `baseRefOid`, `headRefName`, and `headRefOid`.
2. Fetch the exact PR head object through the repository's PR ref when it is not
   available locally. Invoke `git-worktrees`, then run its
   [`worktree-setup.sh`](../git-worktrees/scripts/worktree-setup.sh) helper with
   `--commit "$headRefOid" "review-pr-${pr_number}-${headRefOid:0:12}"`.
   Use one worktree at that object, including for fork pull requests.
3. Fetch the exact base object when needed, then compute the merge base with the PR base.
4. Review `MERGE_BASE..headRefOid`, not `origin/HEAD..HEAD`.
5. Confirm that the worktree `HEAD` equals `headRefOid` before reading files.

Include review threads and any requirements supplied by the user.
Use [`scripts/gather-requirements.sh`](scripts/gather-requirements.sh) for linked issue or ticket context.
Rank sources in this order: user-provided requirements, linked issue or ticket,
explicit acceptance criteria, then PR context.
A general PR summary is context, not acceptance criteria.
If no requirements exist, omit specification review and state that limit; do not block other aspects.
If a requirement source exists but cannot be read, preserve the exact error and
skip only specification review unless that source is mandatory for another aspect.

## Select agents

Run applicable read-only agents in parallel:

| Aspect | Agent | Use when |
| :--- | :--- | :--- |
| `code` | `code-reviewer` | Always |
| `spec` | `spec-reviewer` | Requirements are available |
| `tests` | `test-analyzer` | Behavior changed, even when test files did not |
| `errors` | `silent-failure-hunter` | Error, fallback, retry, or boundary logic changed |
| `types` | `type-design-analyzer` | Types or invariants changed |
| `docs` | `docs-analyzer` | External or developer documentation changed |
| `comments` | `comment-analyzer` | Source comments or docstrings changed |

`all` means every applicable read-only aspect.
Code simplification is a separate implementation task and requires explicit authorization.

Give each agent the requirements, exact diff, changed files, relevant threads, and repository constraints.
Keep agents independent; do not pass one agent's findings to another before aggregation.

## Aggregate and persist

Verify each finding against the exact diff and deduplicate by normalized file, line, and defect.
Keep only actionable findings with evidence and a precise location when available.

Run [`scripts/review-meta.sh`](scripts/review-meta.sh) with the PR number.
Persist the review at its timestamped `outfile` as valid JSON:

```json
{
  "version": 1,
  "timestamp": "<ISO 8601 UTC>",
  "repo": "<owner/repo>",
  "branch": "<head branch>",
  "base_ref": "<base branch>",
  "base_commit_id": "<base SHA>",
  "commit_id": "<PR head SHA>",
  "pr_number": 123,
  "aspects": ["code", "tests"],
  "findings": []
}
```

Use a timestamped path approved by the current environment.
Report the path and the reviewed base/head pair.
Do not offer or perform a GitHub write unless the user explicitly asks to publish the findings.
