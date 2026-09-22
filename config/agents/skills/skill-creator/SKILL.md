---
name: skill-creator
description: >-
  Create, revise, or evaluate agent skills. Use when the user asks to turn a
  workflow into a skill, improve an existing skill, compare skill versions,
  or measure and improve skill selection. Supports the available coding agent
  without requiring a particular provider or model.
---

# Skill creator

Create skills that improve repeatable work without changing the user's scope.
Use the current conversation to identify the intended behavior and existing authorization.
Ask only when a missing choice would materially change the result.

## Choose the execution environment

- Use the tools, skill discovery mechanism, and permissions available in the target coding agent.
  Do not assume a particular CLI, provider, model, tool name, or skill installation path.
- Preserve the selected model and effort unless the user requests a comparison or change.
  Do not infer a CLI model identifier from a conversational model name.
- For evaluation, use fresh agent contexts when available and authorized.
  Keep the model, tools, fixtures, and permissions the same across compared skill versions.
- If fresh contexts or execution tools are unavailable, review examples inline.
  Report that limitation instead of claiming an independent benchmark.

## Create or revise

1. Identify the task, trigger conditions, expected output, and meaningful exclusions.
   Start from supplied examples and corrections. Preserve an existing skill's name and location.
2. Inspect the target skill, nearby conventions, and any referenced tools or resources.
   Snapshot the original before a comparison. Edit the source of generated or installed copies.
3. Write a concise `SKILL.md` with valid `name` and `description` frontmatter.
   Describe when to use the skill without attracting unrelated requests.
   Do not broaden triggers to compensate for an assumed model weakness.
4. Keep shared decisions and constraints in the entrypoint.
   Move substantial optional workflows into linked references with explicit loading conditions.
   Bundle scripts or assets only when they support the actual workflow.
5. Preserve user intent, existing authorization, and supported invocation metadata.
   Check a required dependency before referring to it. Provide a fallback when appropriate.
6. Validate the changed files and verify behavior at a level proportionate to the change.
   A narrow wording fix does not require a full benchmark or a new test suite.

Use [writing-for-agents](../writing-for-agents/SKILL.md) for instruction structure
and [markdown](../markdown/SKILL.md) for Markdown files.
Use available equivalent guidance if these companion skills are not installed.

## Evaluate behavior

For a substantial workflow change or a requested comparison, read
[evaluation.md](references/evaluation.md).
It defines independent runs, baseline comparisons, grading, and the existing viewer tools.

Use realistic requests with observable success criteria.
Include a relevant failure or boundary case when it can expose the changed behavior.
Give evaluators the task, raw inputs, and the skill under test.
Do not supply the intended answer or the suspected failure.

Compare against the original skill or a context without the skill.
Keep other variables fixed. Separate skill quality from changes in model, tools, or permissions.
Use subagents for independent runs when available and authorized.
Run sequentially if concurrency limits require it.

Inspect actual outputs and transcripts. Automate objective assertions where useful.
Report missing telemetry as unavailable. Do not invent token counts or timing fields.
Use the user's feedback when supplied. Silence or an empty feedback field does not imply approval.

Change only instructions supported by the results.
Rerun affected cases after material edits. Expand coverage only for an unresolved concern.
Stop when the requested outcome is met, or explain the remaining limitation.

## Evaluate skill selection

Selection tests must use the target coding agent's real skill discovery and invocation path.
Loading the full skill into an evaluator's prompt tests behavior, not automatic selection.
Do not treat another provider's results as measurements of the current environment.

For a requested selection audit, include relevant requests and plausible near misses.
Keep automatic selection separate from explicit user invocation.
Observe whether the skill was loaded through tool events or another documented trace.
A model's claim that it would use a skill is not invocation evidence.

Use the available agent tools to run these cases.
For repeated CLI evaluations, read [runner.md](references/runner.md) before using
`scripts/run_eval.py`, `scripts/improve_description.py`, or `scripts/run_loop.py`.
These helpers require an explicit adapter command and do not select a provider.
If no compatible adapter or observable selection trace exists, report the gap.
Continue with instruction review and behavior checks that the environment supports.

## Validate and deliver

Run `scripts/quick_validate.py <skill-directory>` with an available Python environment.
Check changed local links, frontmatter, and examples. Run relevant prose checks.
The validator checks structure, not behavioral quality.

Report the changed files, verification evidence, and remaining limitations.
Distinguish static review, simulated execution, and measured model runs.
Do not claim that a skill improves every model from results on one configuration.

Package a `.skill` archive with `scripts/package_skill.py` only when the user needs that artifact.
For an installed skill update, a verified source edit can be the complete deliverable.
Use a writable temporary copy when the supplied installation is read-only.
Do not overwrite the installation without authorization.

## Evaluation resources

- [references/schemas.md](references/schemas.md): artifacts for evaluations, grading, and benchmarks.
- [agents/grader.md](agents/grader.md): grade assertions against observed outputs.
- [agents/comparator.md](agents/comparator.md): compare outputs without revealing version identity.
- [agents/analyzer.md](agents/analyzer.md): explain outcome differences and misleading aggregate scores.

Read each resource only when its evaluation task applies.
