---
name: code-comments
description: >-
  Use when writing, editing, reviewing, or deciding whether to add source-code
  comments, docstrings, declaration documentation, or TODOs.
---

# Code comments

Write for the next maintainer at the declaration or non-obvious block. A useful
comment states a contract, invariant, side effect, constraint, or reason that
the code cannot express clearly.

Load [golang-comments](../golang-comments/SKILL.md) for Go doc syntax and
[writing-docs](../writing-docs/SKILL.md) for documentation outside source.

## Decide before writing

1. Read the code and callers.
2. Verify the behavior from code, tests, or a primary source.
3. Ask what a maintainer could misunderstand.
4. Rename or simplify the code when that removes the need for a comment.
5. Preserve deliberate comments unless the changed code makes them false or
   redundant.

Do not add a comment only because the code was difficult to discover. Search
cost belongs in naming, structure, broader documentation, or the commit.

## Document

Prefer:

- caller obligations and observable results
- invariants and valid states
- ownership, mutation, concurrency, ordering, and caching
- special inputs and failure behavior
- why an error is ignored, wrapped, retried, or escalated
- compatibility or security constraints that govern the local behavior
- the reason for a surprising workaround or measured optimization.

Describe the local contract before upstream history. Mention a dependency only
when its behavior constrains this code. If the source matters, explain the local
effect in plain language and link to a primary reference.

Public declarations follow the language's documentation conventions. Internal
helpers need comments only when their signature, name, and types do not state
the full contract.

## Avoid

Do not:

- narrate control flow or repeat a name, type, or schema field
- copy validation tags, API metadata, or generated schema into prose
- explain a dependency instead of this code
- preserve ticket history that belongs in an issue, commit, or decision record
- defend confusing code that a small refactor can clarify
- add a TODO without an owner, condition, issue, or removal trigger
- state behavior that has not been verified.

Examples should remove real ambiguity. Keep them minimal and executable when
the language supports executable examples.

## Review

Check that each changed comment:

- remains correct when read beside the code
- identifies a contract or reason unavailable from syntax
- uses one stable term for each concept
- does not promise more than tests or implementation details show
- will not drift when generated metadata or a dependency changes.
