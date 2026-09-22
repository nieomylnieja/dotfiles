# Automation runner contract

The selection and description helpers require an explicit `--runner` command.
There is no default provider, CLI, model, or authentication method.
For an evaluation through native agent tools, no adapter is needed.

## Select an adapter

Pass a JSON array of executable arguments. The helpers execute it without a shell.
Use an installed or reviewed adapter for the intended coding agent.
A raw provider CLI is not an adapter unless it implements the protocol below.

The optional `--model` value is opaque and goes to the adapter unchanged.
Omit it to use the adapter's configured model.
Use only an identifier supported by that adapter, not a name inferred from the parent session.
The adapter owns provider settings, credentials, permissions, and trace interpretation.
It must reject unsupported models or operations instead of silently selecting another environment.

Run helper modules from the skill-creator directory with an available Python executable.
This example is schematic: replace the paths with a real adapter and fixtures.

```sh
python -m scripts.run_loop \
  --eval-set /path/to/queries.json \
  --skill-path /path/to/skill \
  --runner '["/absolute/path/to/adapter", "--profile", "evaluation"]' \
  --project-root /path/to/isolated/project \
  --max-iterations 5 --report none
```

`run_eval` uses the same runner, model, and project-root arguments.
`improve_description` requires only the `complete` operation.
Its `--eval-results` input is the JSON output from `run_eval`.
All three commands require `--runner`; earlier implicit CLI invocation is no longer supported.

## Protocol

Each process receives one UTF-8 JSON object on stdin and returns one JSON object on stdout.
Diagnostics belong on stderr. Each request includes `version: 1` and `model` as a string or null.
The working directory is `--project-root`, which defaults to the caller's current directory.
Use an isolated project when evaluations can create files or run tools.

An `evaluate` request has this shape:

```json
{
  "version": 1,
  "operation": "evaluate",
  "model": null,
  "query": "Create a release note for this change",
  "skill_name": "release-notes",
  "skill_path": "/absolute/path/to/release-notes",
  "description": "Write release notes when the user requests them."
}
```

The adapter must:

1. Start a fresh context in the requested environment.
2. Make the skill available through its real discovery mechanism with the candidate description.
   Preserve the skill body and resources. Do not edit the source skill or shared installation.
3. Submit the query without forcing invocation or revealing the expected selection result.
4. Observe invocation through the environment's tool trace or equivalent evidence.
5. Return `{"triggered": true}` or `{"triggered": false}` after a valid observation.

A missing trace, timeout, unsupported operation, or provider failure is an error.
It is not evidence that the skill did not trigger.
The expected `should_trigger` label is not sent to the adapter.
Parallel calls must have separate sessions and temporary discovery state.
The adapter must clean up that state and any remote jobs on completion or cancellation.

A `complete` request contains `operation`, `model`, and `prompt` in addition to `version`.
Return `{"text": "<model output>"}` with nonempty text.
This operation proposes a description from the supplied results and skill content.
It does not measure selection.

For either operation, return a nonzero exit status or `{"error": "diagnostic"}` on failure.
Malformed output and provider errors stop the helper with a nonzero exit status.
They do not enter the pass-rate calculation.
The timeout applies to each adapter process. On POSIX, the helper also stops its process group.

## Interpret results

The loop evaluates candidate descriptions without editing `SKILL.md`.
Training cases inform proposed changes. The separate validation subset selects a candidate.
Because selection uses that subset, its score is not an untouched final test result.
Use fresh cases before claiming broader improvement.

Inspect the proposed description before applying it.
Preserve the rest of the frontmatter and report the measured environment.
Do not equate mock-adapter checks with live provider evaluations.
