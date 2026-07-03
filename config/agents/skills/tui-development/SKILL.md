---
name: tui-development
description: |
  Use this skill when working on terminal UI rendering, interactive CLI prompts,
  ANSI color output, terminal screenshots, Bubble Tea/Lip Gloss/Huh/Glamour,
  curses-style apps, or CLI tests that depend on TTY behavior.
---

# TUI Development

Work from the rendered terminal, not from assumptions.
ANSI output, wrapping, contrast, focus, and prompt behavior must be checked in a
real TTY when they matter to the task.

## Workflow

1. Read the project docs, task runner, existing TUI code, and theme code.
2. Use the project theme or style layer.
   Do not add one-off ANSI, Lip Gloss, or prompt styles when a shared theme
   exists.
3. Run the TUI in a real TTY when changing visual output, interaction, or TTY
   detection.
4. Capture screenshots for contrast or layout changes.
   An image artifact is better evidence than copied ANSI text.
5. Run the project verification target before reporting completion.

## Hyprland Capture

Keep preview and screenshot terminals on the same Hyprland workspace as the
agent terminal.
Record the workspace before any command that can change focus.

Use `hyprctl activewindow -j` or `hyprctl activeworkspace -j` to identify the
current workspace.
Launch the test terminal with a Hyprland exec rule:

```sh
hyprctl dispatch exec "[workspace ${workspace_id} silent] wezterm ..."
```

Use a unique class or title for the test terminal.
Prefer the existing WezTerm screenshot flow over `grim`:
if the environment exposes a WezTerm terminal screenshot command or helper, use
that first because it captures terminal content and theme directly.
Use `grim -g` only when the compositor window, geometry, or non-terminal pixels
are part of what needs review, or when no terminal screenshot helper is
available.

If the workspace cannot be determined, stop and report the exact `hyprctl`
error.
Do not silently open test terminals on another workspace.

## Visual Checks

Check only the states relevant to the change.
Common states:

- first render
- focused selection
- submit or cancel
- error state
- loading state
- narrow and wide terminal widths
- dark and light palettes when color changed

For readability, verify:

- selected and unselected rows are both legible
- muted text is readable
- help hints have enough contrast
- links, headings, and inline code are visible
- wrapping does not hide commands, options, or URLs

Avoid `Faint` unless screenshots prove it works in both dark and light themes.

## Tests

Use semantic tests for behavior:

- exit status
- selected action
- persisted state
- generated files
- stdout and stderr contracts

Use screenshots for human review of contrast and layout.
Do not make image comparison the default automated assertion unless the terminal,
font, palette, size, renderer, and OS are pinned.

For interactive CLI tests, use a PTY when TTY detection changes behavior.
Set fixed `TERM`, width, and color mode.
Drive keys explicitly.

## Handoff Checklist

Before handing work back, report:

- files changed
- verification commands run
- screenshot paths, or the exact blocker
- whether test terminals stayed on the agent terminal's Hyprland workspace
- exact failures from any command that did not pass
