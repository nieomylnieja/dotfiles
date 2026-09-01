---
name: verification-before-completion
description: |
  Use before claiming that work is complete, fixed, correct, or passing,
  and before a commit or pull request that depends on those claims.
---

# Verification before completion

Make each status claim from current evidence.

## Verification gate

1. Inspect the repository instructions, task runners,
   and continuous integration configuration for the changed area.
2. List the claims that the final report will make.
3. Select a safe check for each claim.
4. Run the checks after the last relevant edit.
5. Inspect exit status and the bounded output needed to identify failures.
6. Compare the final diff with the requirements and user-change boundaries.
7. Report passed, failed, and skipped checks with their exact scope.

Prefer project-defined checks because they can supply required flags and environment setup.
Do not run deployment, activation, privileged, network-fetching,
or destructive steps without the required authorization.
If the full continuous integration matrix cannot run locally,
run the safe relevant subset and state the gap.

## Evidence rules

- A previous or partial run does not prove the current full state.
- An agent report is a lead; inspect its diff and rerun the relevant checks.
- A linter does not prove that a build or test suite passes.
- A passing suite does not prove that every requirement is met.
- Evidence becomes stale after a change that can affect its result.
- Keep large logs in a timestamped temporary file and report the failing lines with context.
- Preserve exact error messages. Do not convert a failure into a success claim.

For a regression test, observe the failure before the fix when practical.
If that was not possible, do not edit or revert a dirty shared worktree to manufacture a red run.
Use an isolated checkout or state that the pre-fix failure was not observed.

## Final report

Include:

- files changed;
- verification commands and results;
- exact failures;
- skipped checks and reasons;
- remaining uncertainty or external-state limits.

Qualify claims to match the evidence.
For example, say that targeted tests passed when the full suite did not run.
