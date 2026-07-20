---
name: vhs-gif-creator
description: |
  Create terminal and CLI demo GIFs for READMEs, documentation, release notes,
  tutorials, command walkthroughs, and TUI demonstrations with Charmbracelet
  VHS. Use this skill whenever a GIF should show commands being typed or a
  terminal application being used, and when persisting an accepted VHS demo's
  .tape source and generated .gif. Do not use it for diagrams, math, or general
  programmatic animation; use gif-creator and Manim for those.
---

# VHS GIF Creator

Create terminal demo GIFs with
[Charmbracelet VHS](https://github.com/charmbracelet/vhs).
The `.tape` file is the reproducible source and VHS must generate the final
GIF from it.

## Skill Boundary

Use this skill for terminal sessions, CLI walkthroughs, shell command demos,
and TUIs intended for documentation.
Use [GIF Creator](../gif-creator/SKILL.md) for diagrams, mathematical or
algorithmic animation, and drawn explainers; those assets must use Manim.

If one request needs both a terminal recording and a programmatic animation,
create separate assets with the appropriate skill unless the user explicitly
requires a combined deliverable.

## Safety Boundary

A tape executes real commands on the host.
`Hide` stops frame capture while hidden commands run; it is not a sandbox and
does not grant permission to execute a command.

Before rendering, inspect every typed command and every script it invokes.
Do not run commands that install software, mutate external systems, deploy,
delete data, use secrets, or access the network unless the user explicitly
authorized that operation.
Never record credentials, tokens, private hostnames, or sensitive paths.
Do not use `vhs publish` unless the user explicitly asks to publish the asset.

## Workflow

1. Confirm that the requested asset is a terminal or CLI demonstration.
   Route programmatic animation to GIF Creator.
2. Define the commands, expected output, final dimensions, and documentation
   placement. Keep the demo focused on one short workflow.
3. Audit the tape commands against the safety boundary above.
4. Write the tape in a timestamped scratch directory.
5. Verify that the tape exists, then validate it with `vhs validate`.
6. Render the GIF from the validated tape.
7. Open the rendered GIF directly and inspect the complete terminal flow.
   Fix the tape and repeat until the command flow and final state are correct.
8. Report the configured dimensions and written file size,
   then present the GIF for user review.
9. After the user explicitly accepts the GIF, ask whether to persist the exact
   `.tape` and generated `.gif` by following the opt-in workflow below.

## VHS

VHS is installed by the workstation configuration.
Invoke it directly to validate and render a tape:

```sh
test -f demo.tape
vhs validate demo.tape
vhs demo.tape
```

## Tape Defaults

Start from this dark Nord template and change commands and timing to fit the
requested demonstration:

```text
Output demo.gif

Require mytool

Set Shell "bash"
Set Theme "nord"
Set Width 1200
Set Height 600
Set FontSize 32
Set TypingSpeed 40ms
Set CursorBlink false

Type "mytool status"
Enter
Wait+Screen /ready/
Sleep 1s
```

VHS includes a theme named `nord`.
Prefer it and dark mode unless the user specifies brand colors, a light theme,
or another concrete accessibility or documentation requirement.
Choose dimensions and font size for the actual documentation container;
readability at rendered display size matters more than a fixed resolution.

## Tape Design Rules

- Use `Require` for every external command the demo depends on.
- Set the shell explicitly.
- Prefer deterministic fixtures and local data over live network responses,
  clocks, random values, or mutable external state.
- Use relative paths so the tape remains reproducible from its folder.
- Put necessary setup behind `Hide`. Hidden commands still change terminal
  state and scrollback, so use `Ctrl+L` while still hidden before `Show` when
  setup output must not remain in the visible viewport. `Ctrl+L` does not erase
  scrollback; keep the visible demo from scrolling back into hidden output or
  use a verified terminal-specific clearing mechanism. Hidden setup remains
  subject to the same authorization rules.
- Prefer `Wait+Screen` with a specific regular expression for output whose
  completion time varies. `Wait+Line` examines only the current line and can
  miss output after the prompt returns. Use short `Sleep` commands only for
  pacing.
- Show the initial command, the meaningful output, and a stable final state.
- Keep terminal width narrow enough that important output does not wrap.
- Do not depend on personal shell history, aliases, prompts, or dotfiles.

## Verification Loop

Validation is necessary but does not execute the tape or prove the visual is
correct. Before claiming completion:

1. Verify that the `.tape` file exists and `vhs validate` exits successfully.
2. Render the tape and verify that the expected `.gif` exists.
3. Open the rendered GIF directly and inspect the complete terminal flow.
4. Confirm that commands and output are readable, no sensitive information is
   visible, no content is clipped, the final state is held long enough, and
   the loop reset is acceptable for the documentation context.

Any failure requires a tape change, another render, and another verification
pass. If a check cannot be performed, report the exact failure and do not call
the GIF verified.

## Opt-in Demo Persistence

The persistent source repository is
[nieomylnieja/giffs](https://github.com/nieomylnieja/giffs).
Acceptance of the visual does not authorize repository changes.
After the user explicitly accepts the GIF, ask one scoped question:

> Do you want me to persist `<slug>.tape` and `<slug>.gif` as
> `giffs/<slug>/` in `nieomylnieja/giffs` and commit and push it directly to
> `main`?

Do not clone, edit, commit, or push to that repository unless the user answers
yes. That answer authorizes only the new-folder commit described in the
question; it does not authorize changes to existing GIFs or repository-wide
files.

After confirmation:

1. Work from a clean, current checkout of `main` and verify that its upstream
   is `origin/main`. Stop on a dirty tree, divergence, a non-fast-forward
   state, authentication failure, or network failure.
2. Choose a descriptive, unique, kebab-case path under `giffs/`.
   Stop if `giffs/<slug>/` already exists; never merge into or replace it.
3. Copy the exact accepted tape to `giffs/<slug>/<slug>.tape` and its verified
   output to `giffs/<slug>/<slug>.gif`.
   Add only fixtures or assets required to reproduce the tape, and keep every
   added file inside that folder.
4. Before staging, verify that every working-tree change is a newly added path
   beneath `giffs/<slug>/`. Stop if any other path is changed.
5. Stage only `giffs/<slug>/`, then verify every staged path has that prefix.
   Do not update the root README, an index, another GIF folder, or any other
   repository file.
6. Follow the Git Commit skill: show the staged files and proposed
   `feat: add <slug> terminal demo` message, then obtain its required
   interactive confirmation. Commit on `main` only after confirmation and
   verify that the commit contains only the new folder.
7. Push `main` to `origin` normally. Never force-push. If the push is rejected
   because `main` moved, stop and report it rather than rebasing or modifying
   other GIFs automatically.
8. Report the folder URL and commit hash. If any step fails, report the exact
   command failure and leave unrelated paths untouched.
