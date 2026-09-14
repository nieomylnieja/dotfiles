---
name: testing
description: >-
  Use when choosing a test level, designing or reviewing test coverage, or
  deciding whether a behavior needs a new test. Owns shared testing policy
  across languages and frameworks.
---

# Testing

Choose the test boundary and coverage before selecting language or framework
patterns. Use the repository's established test suites and conventions.

## Choose the test level

1. Identify the public behavior and the regression that a test must detect.
2. Inspect existing coverage and the available test entrypoints.
3. Test through the highest practical level that exercises that behavior.
4. Select a focused scenario within that level.

For CLI behavior, invoke the real command through the repository's CLI suite.
For API behavior, exercise the API boundary. For library behavior, use its
public interface. A private function or internal package does not determine
the test level.

A focused test limits its scenario, not necessarily its integration boundary.
Calling internal constructors and checking mocked requests does not replace
coverage of behavior that the public entrypoint can test.

Use a lower-level test when the higher level cannot exercise a relevant case
reliably. State the concrete constraint before adding it. Examples include
unexposed parser edge cases, controlled transport failures, or internal batch
boundaries that the public response cannot reveal.

After choosing the boundary, load the relevant language or framework skill
for implementation conventions.

## Choose coverage and assertions

- Extend existing coverage before adding a separate test path.
- Assert observable outcomes and contracts. Avoid assertions about incidental
  call order, private structure, or implementation steps.
- Cover relevant success, invalid input, dependency failure, and cleanup paths.
  Keep each scenario small enough that a failure identifies the broken behavior.
- Name tests for their conditions and expected outcomes.
- Add coverage at another level only when it detects a distinct failure.
  Avoid repeating the same contract through both public and internal entrypoints.
- Use test doubles at dependency boundaries when controlled responses are
  necessary. Preserve the real path through the behavior under test.

## Separate test design from execution limits

Keep unit tests deterministic and offline. Classify tests that need services,
credentials, or mutable external state under the repository's integration rules.

When credentials, services, or permission are unavailable, write the test at
the appropriate level and report it as unrun. That execution limit does not
justify duplicate unit tests for the same behavior.

Use [verification-before-completion](../verification-before-completion/SKILL.md)
to select permitted checks and report the evidence for completion claims.
