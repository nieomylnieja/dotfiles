---
name: testing
description: >-
  Mandatory for code reviews, including reviews with no test-file changes.
  Also use when choosing a test level, designing test coverage, or deciding
  whether a behavior needs a new test. Owns shared testing policy across
  languages and frameworks.
---

# Testing

Choose the test boundary and coverage before selecting language or framework
patterns. Use the repository's established test suites and conventions.
Load this skill before review analysis, even when test files are unchanged.
Apply its test-review checks within the assigned scope.

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
When an integration test can cover the same behavior reliably, prefer it to
a unit test of the implementation. Convenience alone does not justify a lower level.

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

## Review tests

Judge tests against the required behavior, not only the current implementation.
For each relevant behavior and its existing or proposed coverage:

1. Establish the expected outcome from user requirements, documented contracts,
   or other independent evidence. If the contract is unclear, report the question.
2. Check the test level against the public entrypoint and available integration suites.
   Identify any concrete constraint that requires a lower level.
3. Name a plausible regression that the test detects. Flag redundant tests,
   assertions that repeat the implementation, and mocks that bypass the behavior.
   Recommend consolidation or removal when a test adds no meaningful protection.
4. Compare assertions with the expected outcome. A passing test that encodes a
   known defect needs a corrected expectation, even if that makes the test fail.
   For a regression test, check that it fails for the defect and passes for the correction.
   Distinguish executed evidence from reasoning when a safe failure check is unavailable.
5. Check repository conventions for suites, helpers, fixtures, assertions, naming,
   isolation, and test doubles. Accept departures only within an explicitly authorized
   change, such as a test-suite refactor.

Recommend a focused scenario at the highest practical level. Existing coverage
can be sufficient. Avoid tests for trivial behavior, duplicate contracts, or
exhaustive combinations without a concrete risk. A missing test alone does not
prove a production defect, and a passing suite does not prove the contract is correct.

## Separate test design from execution limits

Keep unit tests deterministic and offline. Classify tests that need services,
credentials, or mutable external state under the repository's integration rules.

When credentials, services, or permission are unavailable, write the test at
the appropriate level and report it as unrun. That execution limit does not
justify duplicate unit tests for the same behavior.

Use [verification-before-completion](../verification-before-completion/SKILL.md)
to select permitted checks and report the evidence for completion claims.
