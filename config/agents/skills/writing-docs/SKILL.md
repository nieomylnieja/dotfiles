---
name: writing-docs
description: |
  Use this skill whenever you need to write or rewrite technical documentation:
  code comments, doc comments, docstrings, README sections, runbooks,
  design notes, API docs, onboarding docs, or troubleshooting guides.
  Use it when the documentation must be both technically correct and easy to read,
  especially if the draft is becoming vague, academic, or hard to scan.
---

# Writing Technical Documentation

Write documentation so a busy engineer can act correctly after one pass.
Optimize for two things at the same time:

- technical correctness
- ease of understanding

A document can be factually correct and still be poor documentation
if the reader has to decode it like a paper.

## Workflow

1. Verify the source of truth.
2. Identify the reader and their question.
3. Write the smallest document that answers that question well.

## Verify Before Writing

- Check the code, commands, config, interface, ticket, or other source material first.
- Do not invent behavior, defaults, examples, or rationale.
- If something cannot be verified, say what still needs checking.

## Write for the Reader

- Decide who the document is for:
  maintainer, reviewer, operator, API consumer, or new contributor.
- Write to the task or decision the reader is trying to complete.
- Put prerequisites before steps,
  caveats next to the behavior they affect,
  and procedures in execution order.

## Style

- Prefer plain language, short sentences, and concrete verbs.
- Use technical terms when they help precision,
  but do not hide simple ideas behind formal or academic phrasing.
- Lead with the important point.
- Explain contracts, assumptions, invariants, side effects,
  failure modes, and non-obvious tradeoffs.
- Cut filler, throat-clearing, and text that only restates obvious code.

## Examples

- Use examples when they remove ambiguity.
- Keep them minimal and accurate.
- Ensure commands, identifiers, paths, and outputs match the current system.
- If an example is schematic rather than exact, label it clearly.

## By Document Type

### Comments and Docstrings

- Document the external contract, not the line-by-line implementation.
- Explain meaning, expectations, and edge cases.
- Remove comments that merely narrate obvious code.

### READMEs and Guides

- Optimize for task completion.
- Include prerequisites, the happy path,
  and the first likely failure mode or troubleshooting clue.
- Use headings that match the questions readers actually ask.

### Design Docs and Decision Records

- State the problem, constraints, decision, and tradeoffs.
- Separate facts from open questions.
- Call out non-goals so the scope stays clear.

## Maintenance

- Prefer stable behavior over transient implementation detail.
- Avoid version-sensitive claims unless you include the scope.
- Delete stale TODOs and outdated transitional notes
  instead of writing around them.

## Final Check

- Can the reader understand the point from the first paragraph?
- Did you verify each factual claim?
- Did you replace vague or academic wording with direct language?
- Did you cut text that adds no operational or explanatory value?

## Coordinate With Other Skills

- For Markdown formatting and link conventions, also load the `markdown` skill.
- For Go doc comments, also load the `golang-comments` skill.
