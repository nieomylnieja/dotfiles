---
name: markdown
description: >-
  Use when creating, editing, or reviewing Markdown files, including README,
  documentation, and SKILL.md files. Do not invoke for chat formatting alone.
allowed-tools: Bash(markdown-link-check *) Bash(markdownfmt *) Bash(markdownlint *)
---

# Markdown

Follow the repository's Markdown dialect, formatter, linter, and nearby file
style. Load [ste-writing](../ste-writing/SKILL.md) for English prose and
[writing-docs](../writing-docs/SKILL.md) for technical documentation.

## Preserve the document

- Confirm whether the file is generated before editing it.
- Preserve frontmatter keys, anchors, reference labels, directives, and
  platform-specific extensions.
- Keep established heading capitalization, line wrapping, list markers, and
  code-fence style unless the task changes the document broadly.
- Do not reflow unrelated paragraphs.
- Search for existing documentation before adding another source of truth.

## Structure

- Use one clear title when the document type expects one.
- Keep heading levels sequential.
- Use headings instead of horizontal rules for document structure.
- Keep paragraphs focused and separate blocks with blank lines.
- Use a list for parallel items and numbered steps for ordered procedures.
- Use a table only when readers need to compare values across repeated fields.

Write link text that identifies the destination. Add links when they help a
reader verify or continue a task, not for every technical term. Prefer primary
sources for technical claims.

## Code and commands

- Add a language identifier to fenced code when one exists.
- Introduce non-obvious examples and state expected output when it matters.
- Keep exact commands, identifiers, errors, and literals unchanged.
- Do not publish an untested command as a verified procedure.
- Use inline code for identifiers and short literals, not for emphasis.
- Keep copied output short and relevant.

Use four-space indentation only when the surrounding file requires it. Fenced
blocks are clearer for most examples.

## Links, images, and HTML

- Use relative links for repository files when the publishing system supports
  them.
- Check changed local links and anchors.
- Give informative images concise alt text. Use empty alt text only for a
  decorative image.
- Avoid raw HTML when Markdown expresses the same structure. Preserve required
  HTML used by the target renderer.
- Do not add `target="_blank"`; the reader controls link behavior.

## Line wrapping

Use the project's existing policy. Semantic line breaks can make prose diffs
easier to review, but they are not mandatory and can conflict with GitHub form
fields, generated text, tables, long links, and projects that keep one paragraph
per line.

When the project uses semantic line breaks, wrap at sentence or clause
boundaries. Do not split identifiers, links, inline code, or a sentence solely
to satisfy an arbitrary column.

## SKILL.md files

Keep frontmatter valid and descriptions specific enough to distinguish adjacent
skills. Put trigger conditions in the description. Keep the body focused on
decisions and actions that change agent behavior; move long reference material
to a named resource with clear loading conditions.

Do not copy a full external style specification into a skill. Summarize the
applicable rule and link to its source when attribution or detail matters.

## Verify

Run the repository formatter and Markdown linter on changed files. Also check:

- frontmatter parses;
- fences and directives are balanced;
- changed links and anchors resolve;
- examples match the documented interface;
- the rendered structure is correct when the change depends on renderer-specific
  behavior.

Limit formatting to changed Markdown files. Report formatter or linter failures
instead of applying an unscoped rewrite.
