---
name: code-comments
description: |
  Use this skill whenever writing, editing, reviewing, or deciding whether to add
  code comments, docstrings, inline comments, or internal function documentation
  in any programming language. Use it even when the task only mentions
  "comments", "docs in code", "docstrings", "document this function", or
  "explain this helper".
---

# Code Comments

Write comments for the next maintainer reading the code at the call site,
the declaration, or the non-obvious block.
The comment should help them use, change, or debug the code correctly without
reconstructing hidden context.

When working with Go code, also use `golang-comments`.

## Workflow

1. Read the code before writing the comment.
2. Identify the reader's immediate question.
3. Decide whether better naming, types, or structure would remove the need for
   the comment.
4. If a comment is still useful, document the code in isolation first:
   what it promises, assumes, returns, mutates, rejects, or preserves.
5. Add upstream context only when it changes the contract this code exposes.

## What To Document

Prefer comments that explain:

- External contracts and caller obligations
- Invariants that must survive future edits
- Preconditions, postconditions, and edge cases
- Side effects, mutation, ownership, caching, concurrency, or ordering
- Failure modes and why errors are ignored, wrapped, retried, or escalated
- Non-obvious rationale for a local decision
- Compatibility constraints with a named upstream or downstream system when
  the current code's behavior depends on that constraint

Avoid comments that:

- Narrate the next line of code
- Repeat names, parameters, or types without adding meaning
- Describe how a dependency works instead of what this code does
- Encode historical debugging notes that belong in a commit, issue, or ADR
- Defend confusing code that should be renamed, split, or simplified
- Speculate about behavior that has not been verified

## Document The Code In Isolation

Start from the declaration or block being commented.
A good comment should still make sense if the reader has not memorized the
upstream service, ticket, or bug report that led to the implementation.

For a function or method, describe its own contract:

- What it returns or changes
- Which inputs are special
- Which invariants it enforces
- Which errors or rejection cases callers should expect
- Which observable behavior downstream code can rely on

Do not make the upstream dependency the subject unless the function is itself
an adapter around that dependency.
Mention upstream behavior only to explain a local contract:
"drops absent-label matchers that match the empty string" is local behavior;
"handles `/label/<label_name>/values`" is upstream routing context and usually
does not belong in an internal helper's opening sentence.

## Internal Functions

Internal helpers usually need less ceremony than public APIs.
Comment them only when the signature and name cannot carry the full contract.

When commenting an internal function:

- Lead with the helper's own responsibility.
- Keep implementation strategy out of the summary sentence.
- Put dependency-specific constraints after the local behavior,
  and only when future edits need that context.
- Prefer one or two precise sentences over a multi-paragraph comment.

Red flag:

```go
// filterValidItems returns items that can be sent to ExternalService.
//
// It is the compatibility gate for ExternalService's batch endpoint and legacy
// retry path. It preserves items accepted by ExternalService, drops items only
// when ExternalService treats them as missing, and rejects the request
// otherwise.
```

This comment documents upstream routing and compatibility framing before it
documents the helper's isolated behavior.
Prefer wording shaped around the helper:

```go
// filterValidItems keeps items that satisfy the local validation rules.
// It rejects the batch when a required item is invalid.
```

If the `ExternalService` constraint is essential, put it in the caller,
adapter, package documentation, or a later sentence that explains why this
helper has that contract.

## Inline Comments

Inline and block comments should explain why a surprising local choice is
necessary.
They should be rare.

Use them for:

- Workarounds for specific bugs or platform behavior
- Performance, allocation, locking, or ordering constraints
- Security-sensitive checks whose placement matters
- Intentional deviations from a common pattern
- Error handling that would otherwise look accidental

Do not use them for:

- Simple control flow
- Restating a condition in prose
- Section headers for short functions
- TODOs without an owner, condition, or removal trigger

## Docstrings And Declaration Comments

For public or exported declarations, follow the language ecosystem's doc
comment conventions.
Describe the stable contract, not private implementation details.

Include examples only when they remove ambiguity.
Keep examples minimal and executable or clearly schematic.

For Go code, load [golang-comments](../golang-comments/SKILL.md) in addition
to this skill.
Use that skill for Go-specific syntax, doc links, headings, lists, and
deprecation formatting.

## Relationship To Writing Docs

For broader technical documentation such as READMEs, runbooks, design docs,
API guides, and troubleshooting guides, use
[writing-docs](../writing-docs/SKILL.md).

Use this skill for documentation embedded in source code.
When a task spans both source comments and external documentation,
use both skills and keep the comment focused on the code's local contract.

## Final Check

- Does the comment describe this code before its dependencies?
- Would the comment still help if dependency names changed?
- Does every dependency reference explain a local contract or constraint?
- Could naming, types, or a small refactor delete the comment?
- Is every factual claim verified against code or source material?
