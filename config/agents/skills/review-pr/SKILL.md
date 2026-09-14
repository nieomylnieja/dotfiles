---
name: review-pr
description: |
  Run a read-only review through a coordinator and independent specialist agents.
  Use when asked to review a PR, assess merge risk, or review selected code, test,
  error-handling, security, type, documentation, comment, or specification aspects.
allowed-tools: Bash(*scripts/gather-requirements.sh*) Bash(*scripts/review-meta.sh*) Bash(jira issue view*) Bash(mkdir -p */agents/pr-review/*) Edit(**/agents/pr-review/*/*.json) Write(**/agents/pr-review/*/*.json)
---

# Pull request review

The main session prepares the target and launches one `review-coordinator`. The coordinator
owns specialist selection, optional adversarial review, verification, and the final verdict.
If you are already that coordinator, read [the coordinator workflow](references/coordinator.md)
and start there. A specialist follows its assignment without dispatching another review.

Review requests authorize read-only investigation, fetching missing Git objects, isolated
review setup, and local review artifacts. They do not authorize repository-content edits,
thread changes, or GitHub review posts.

## Prepare the handoff

1. Read PR metadata: number, `baseRefName`, `baseRefOid`, `headRefName`, and `headRefOid`.
2. Reuse a supplied review worktree only after confirming its `HEAD` equals `headRefOid`.
   Otherwise, fetch the exact PR head through the repository's PR ref and invoke `git-worktrees`.
   Run its [`worktree-setup.sh`](../git-worktrees/scripts/worktree-setup.sh) helper with
   `--commit "$headRefOid" "review-pr-${pr_number}-${headRefOid:0:12}"`.
   Use this exact object for fork pull requests too.
3. Fetch the exact base object when needed, then compute its merge base with the PR head.
   Review `MERGE_BASE..headRefOid` and confirm the worktree `HEAD` before reading files.
4. Collect user requirements and relevant review threads. Use
   [`scripts/gather-requirements.sh`](scripts/gather-requirements.sh) for linked issue or ticket context.

For a local or branch review, use the requested files, working tree, or commit range instead
of PR setup. Record staged, unstaged, and relevant untracked content when that is the target.
Identify the reviewed snapshot and detect changes before delivery; never invent PR metadata.

Give the coordinator a factual handoff containing:

- the checkout path, exact target and base, changed-file summary, and accessible diff;
- the requested aspects, user constraints, and applicable repository instructions;
- requirements with source references, source-access errors, and relevant check results;
- the resolved absolute path to this skill and its coordinator reference;
- the selected reasoning effort, reason, and available concurrency;
- for re-review, the prior review and thread data, marked for comparison after the fresh review.

Rank requirements by user instructions, linked issue or ticket, explicit acceptance criteria,
then PR context. A general summary is context, not acceptance criteria. Missing requirements
limit specification review. An unreadable source must retain its exact error and the affected scope.
Exclude implementation self-assessments and other reviewers' conclusions from the initial brief.

## Select reasoning and dispatch

Choose the coordinator's effort from the review's risk and ambiguity:

| Effort | Use when |
| :--- | :--- |
| `xhigh` | Requirements are clear and behavior has limited interactions |
| `max` | Security, concurrency, migrations, broad behavior changes, or conflicting evidence |
| `ultra` | A consequential question remains after investigation and the runtime supports it |

Honor an explicit user choice. Otherwise, this skill authorizes the main session to select
the supported effort at spawn and record the reason. Inherit the main session's model unless
the user or project specifies another. Keep specialist effort settings independent.

Use a fresh coordinator context with the handoff. In Codex, set `fork_turns="none"` and pass
`reasoning_effort` explicitly when those controls are available. Full-history forks inherit
the parent's settings. The coordinator definition deliberately leaves model and effort unset
because custom-role settings take precedence over spawn settings.

Read actual tool capabilities before dispatch. If an effort is unsupported, use the closest
supported level and disclose it. If effort overrides are unavailable, record inheritance
instead of claiming that the requested setting took effect. Record resolved effort only when
the runtime exposes it. These controls are described in the
[Codex subagent documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents#custom-agents).

Reserve capacity for the coordinator and queue specialists within the remaining session limit.
The coordinator and its leaf reviewers form two delegation levels even when the runtime permits
more. If nested delegation is unavailable, the main session runs the coordinator workflow with
direct specialists and records that fallback. If delegation itself is unavailable, report the
independence limit and complete the permitted review without claiming specialist coverage.

## Support and deliver

Keep the review target stable while the coordinator works. Handle requests for missing context
and permitted checks, returning the exact command, target, result, and failures. The coordinator
retains responsibility for interpreting that evidence. New consequential uncertainty can justify
a higher-effort replacement coordinator or a bounded arbitration agent. Pass the evidence and
remaining question, preserve completed coverage, and keep only one active coordinator.
Use runtime controls for effort changes when available; a follow-up message alone is not one.

Receive the coordinator's final report as defined in
[the report contract](references/coordinator.md#return-the-verdict).
For PRs, run [`scripts/review-meta.sh`](scripts/review-meta.sh) with the PR number and compare
its base/head pair with the reviewed pair before writing the JSON to its timestamped `outfile`.
If either changed, review the new target before delivering a current verdict. Confirm the
checkout or local snapshot still matches too. For local reviews, report the actual target and
use an environment-approved artifact path only when persistence is needed.

Persist and present the coordinator's verified result, including coverage, adversarial decisions,
reasoning selection, checks, and limitations. Return contradictions or unsupported findings to
the coordinator for correction. For re-review, persist only its final filtered report.
Report the path and exact target. Publish only after an explicit user request.
