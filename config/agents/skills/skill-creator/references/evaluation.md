# Evaluate skill behavior

Use this workflow for a substantial skill change or a requested benchmark.
Scale the case count and repetitions to the behavior under review.

## Prepare the comparison

Use a temporary workspace outside the skill directory.
Save the original skill when comparing a revision.
Define realistic requests, raw input files, and expected outcomes in `evals/evals.json`.
See [schemas.md](schemas.md) for the artifact formats.

For each case, use a fresh context with the candidate skill and a separate baseline context.
The baseline uses the original skill for a revision, or no skill for a new skill.
Keep the task, model settings, tools, and permissions equivalent.
Record the provider, coding agent, model, and effort when the runtime exposes them.
Mark unknown values as unavailable.

Example handoff:

```text
Complete this task using the supplied skill.
Task: <realistic user request>
Skill: <candidate or baseline path>
Inputs: <raw artifacts>
Permitted side effects: <scope>
Save outputs and a transcript to: <run directory>
```

Do not reveal the expected answer or the comparison hypothesis to the executor.
For a no-skill baseline, omit the skill and ensure that it is not loaded automatically.
An agent that already read the candidate cannot serve as an independent baseline.

Organize runs as `iteration-N/eval-ID/{with_skill,without_skill,old_skill}/run-N/`.
Use only the applicable baseline directory.
Each run contains `outputs/`, a transcript, and any available timing data.
Record the prompt and assertions in each run's `eval_metadata.json`.
Do not substitute zero for unavailable token or time measurements.

## Grade and inspect

Use [the grader instructions](../agents/grader.md) for assertions against actual outputs.
For consequential comparisons, use an independent grader when available and authorized.
Keep deterministic checks in scripts when they can verify the output reliably.
In `grading.json`, expectation entries use `text`, `passed`, and `evidence`.

The aggregation helper requires complete timing and token measurements for comparable runs.
Put `total_duration_seconds` and `total_tokens` in each run's `timing.json`.
Omit the redundant `timing` block from `grading.json` so the helper reads that file.
If telemetry is incomplete, report assertions and outputs directly without a benchmark file.

With complete measurements, aggregate from the skill-creator directory:

```sh
python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>
```

Use the Python executable available in the environment.
Verify every aggregate time and token value against the raw measurements before interpreting it.
The helper can substitute zeros or output character counts for missing telemetry.
Do not report those fallback values as measurements. Report excluded runs explicitly.
Consult [the analyzer instructions](../agents/analyzer.md) for variance and weak assertions.

For a review with many outputs, generate the existing static viewer:

```sh
python eval-viewer/generate_review.py <workspace>/iteration-N \
  --skill-name <name> --static <workspace>/review.html
```

Add `--benchmark <workspace>/iteration-N/benchmark.json` when the benchmark exists.
Add `--previous-workspace <workspace>/iteration-M` when comparing iterations.
For a small review, present the outputs directly instead of creating a viewer.
Use the interactive viewer only when a browser and local server are appropriate.

Read feedback from the user or an exported `feedback.json` when provided.
An empty comment is not proof of acceptance or correctness.
Apply supported improvements and rerun the affected cases.
Keep observed performance claims limited to the tested environment and cases.
