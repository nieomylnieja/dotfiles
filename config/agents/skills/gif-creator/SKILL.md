---
name: gif-creator
description: |
  Create drawn and programmatic animated GIFs through Manim: diagrams, math,
  algorithm visualizations, and explainers. Use this skill for animated
  diagrams, visual explanations, and Manim source persistence after accepting
  a GIF. Do not use it for terminal or CLI demo recordings; use
  vhs-gif-creator for those.
---

# GIF Creator

Create animated GIFs with [Manim Community](https://www.manim.community/).
Manim is the complete rendering pipeline for every GIF in this skill's domain.
Do not assemble, edit, optimize, or inspect GIFs with another rendering
pipeline.

The goal is correctness — accurate shapes, labels, and motion —
not decorative effects.
An animation that shows the right thing plainly
beats a flashy one that misleads.

## Skill Boundary

Use this skill for diagrams, mathematical or algorithmic animations,
and drawn explainers.
Use [VHS GIF Creator](../vhs-gif-creator/SKILL.md) when the requested visual is
a terminal session, CLI walkthrough, TUI demonstration, or command recording
for documentation.

If one request needs both a terminal recording and a programmatic animation,
create separate assets with the appropriate skill unless the user explicitly
requires a combined deliverable.

## Workflow

1. Confirm that the requested asset belongs to the Manim domain above. Route
   terminal and CLI recordings to VHS GIF Creator.
2. Pin down what the animation must show: elements, labels, motion, duration.
3. Write the scene in a scratch directory, using the dark Nord default below
   unless the user or subject requires another palette.
4. Render a low-quality draft GIF.
5. Run the verification loop below; fix and re-render until correct.
6. Only then adjust resolution or size for the target.
7. Report the render settings and file size.
8. Present the result for user review.
9. After the user explicitly accepts the GIF, ask whether to persist its Manim
   source by following the opt-in workflow below.

## Manim

Manim is installed by the workstation configuration.
Invoke it directly.

Render a scene directly to GIF:

```sh
manim render -ql --format=gif scene.py SceneName
```

Output lands at
`media/videos/<script-stem>/<res>/<SceneName>_ManimCE_v<version>.gif`
(manim prints the exact path as "File ready at").

| Flag           | Effect                                              |
| :------------- | :-------------------------------------------------- |
| `-ql`          | 854x480 @ 15 fps — right default for GIF drafts     |
| `-qm`          | 1280x720 @ 30 fps — larger files, rarely needed     |
| `-r W,H`       | custom resolution, e.g. `-r 480,270`                |
| `-o name`      | output basename (`name.gif`)                        |
| `--format=gif` | required; manim renders MP4 otherwise               |

Minimal scene:

```python
from manim import *

NORD = {
    "nord0": "#2e3440",
    "nord1": "#3b4252",
    "nord2": "#434c5e",
    "nord3": "#4c566a",
    "nord4": "#d8dee9",
    "nord5": "#e5e9f0",
    "nord6": "#eceff4",
    "nord7": "#8fbcbb",
    "nord8": "#88c0d0",
    "nord9": "#81a1c1",
    "nord10": "#5e81ac",
    "nord11": "#bf616a",
    "nord12": "#d08770",
    "nord13": "#ebcb8b",
    "nord14": "#a3be8c",
    "nord15": "#b48ead",
}


class Diagram(Scene):
    def construct(self):
        self.camera.background_color = NORD["nord0"]
        box = Square(color=NORD["nord8"])
        label = Text(
            "queue", color=NORD["nord6"], font_size=36
        ).next_to(box, DOWN)
        self.play(Create(box), Write(label))
        self.wait(1.1)
```

### Visual Defaults

Prefer dark mode with the canonical
[Nord palette](https://www.nordtheme.com/docs/colors-and-palettes/).
Use `nord0` for the background, `nord6` for primary text,
`nord4` or `nord5` for secondary text, and `nord8` as the primary accent.
Use the remaining Frost colors (`nord7` through `nord10`) sparingly
to distinguish related elements.
Reserve Aurora colors (`nord11` through `nord15`) for semantic states such as
errors, warnings, success, or a category that needs clear separation.

This is a preference, not a reason to disregard an explicit palette,
brand requirement, source-image colors, accessibility requirement,
or domain convention from the user.
When deviating from Nord without an explicit user request,
state the concrete readability or semantic reason.

### Correctness Rules

- The frame is 8 units tall and ~14.2 wide, centered on the origin.
  Position with `.to_edge()`, `.next_to()`, `.shift()`,
  and verify nothing is clipped or overlapping.
- `MathTex`/`Tex` require a LaTeX toolchain.
  Check `command -v latex` first; when absent, use `Text`.
- GIF duration = sum of `run_time` (default 1 s per `self.play`)
  plus `self.wait()` calls. Keep it 2-6 s.
- GIFs loop infinitely by default.
  For a seamless loop, the final visual state must match the first frame;
  a wait does not repair a mismatched transition.
  If a visible reset is intentional, add a short `self.wait()` and describe it
  as an intentional reset rather than a seamless loop.
- Prefer few precise animations (`Create`, `Write`, `Transform`,
  `FadeIn`, `MoveTo`/`animate`) over layered effects.
- Text must stay readable at final display size; `font_size=36`
  at 480p is a safe floor.

## Verification Loop

Mandatory before claiming completion.

1. Verify that Manim exits successfully and prints the output GIF path.
2. Open the rendered GIF directly and inspect the complete animation.
3. Confirm:

   - every requested element is present and labeled as asked
   - nothing is clipped by the frame edge or overlapping illegibly
   - the motion matches the requested behavior
   - the start and end connect if the loop should be seamless

4. Report the resolution and frame rate selected through Manim,
   the intended scene duration, and the written file size.

Any failure: fix the scene, re-render, verify again.
If a check cannot be performed, say exactly which one and why —
never report an unverified GIF as done.

## External Sources

Load supported static images into the scene as `ImageMobject` instances.
The resulting GIF must still be rendered directly by Manim.
Do not assemble frame sequences or post-process Manim output with another GIF
library. If the requested edit cannot be expressed as a Manim scene,
state that limitation instead of silently switching pipelines.

## Size Control

Dimensions, duration, and frame rate dominate GIF size.
When the file is too large, in order:
shorten the animation, lower the Manim frame rate,
then render at a lower resolution with `-r`.
Do not shrink past the point where labels stop being readable.

## Opt-in Source Persistence

The persistent source repository is
[nieomylnieja/giffs](https://github.com/nieomylnieja/giffs).
Never infer persistence permission from approval of the visual itself.
After the user explicitly accepts the GIF, ask one scoped question:

> Do you want me to persist the Manim source as `giffs/<slug>/` in
> `nieomylnieja/giffs` and commit and push it directly to `main`?

Do not clone, edit, commit, or push to that repository unless the user answers
yes. That answer authorizes only the new-folder commit described in the
question; it does not authorize changes to existing GIFs or repository-wide
files.

After confirmation:

1. Work from a clean, current checkout of `main` and verify that its upstream is
   `origin/main`. Stop on a dirty tree, a non-fast-forward state, divergence,
   authentication failure, or network failure.
2. Choose a descriptive, unique, kebab-case path under `giffs/`.
   Stop if `giffs/<slug>/` already exists; never merge into or replace it.
3. Copy the exact Manim scene to `giffs/<slug>/scene.py`.
   Add only local modules, source assets, fonts, or brief reproduction metadata
   that are actually required, and keep every added file inside that folder.
   Do not add rendered media or caches unless the user explicitly requests it.
4. Before staging, verify that every working-tree change is a newly added path
   beneath `giffs/<slug>/`. Stop if any other path is changed.
5. Stage only `giffs/<slug>/`, then verify every staged path has that prefix.
   Do not update the root README, an index, another GIF folder, or any other
   repository file.
6. Commit on `main` with `feat: add <slug> gif source` and verify the commit
   contains only the new folder.
7. Push `main` to `origin` normally. Never force-push. If the push is rejected
   because `main` moved, stop and report it rather than rebasing or changing
   other GIFs automatically.
8. Report the folder URL and commit hash. If any step fails, report the exact
   command failure and leave unrelated paths untouched.
