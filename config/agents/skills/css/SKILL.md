---
name: css
description: Use when reading, writing, reviewing, or debugging CSS and CSS-producing UI code.
---

# CSS

Follow the project's design system, browser support policy, build pipeline, and
existing CSS conventions. Inspect the rendered component and nearby styles
before changing a rule.

## Implement

- Prefer semantic HTML and native layout before adding CSS workarounds.
- Use existing design tokens for color, spacing, type, radii, and motion.
- Choose units by purpose. Use `rem` for user-scalable type and spacing, `%` or
  viewport/container units for fluid layout, and `px` when a physical CSS pixel
  is the intended constraint.
- Use logical properties when the interface supports different writing modes.
- Keep selector specificity low. Do not add `!important` until you identify why
  normal cascade rules cannot express the override.
- Preserve component boundaries. Avoid global selectors for local behavior.
- Prefer container queries when a component responds to its own available
  space. Use media queries for viewport or user-preference conditions.
- Respect `prefers-reduced-motion`, forced colors, zoom, keyboard focus, and
  sufficient contrast.

Do not replace a clear fixed design with fluid calculations mechanically.
Do not introduce a new naming method, reset, framework, or token layer for a
local change.

## Verify

Run the project's formatter, linter, and UI tests. Inspect affected states at
representative widths, including overflow, long text, focus, hover, disabled,
error, dark mode, and reduced motion when applicable. Use browser automation or
screenshots only when the user permits the required GUI or browser action.
