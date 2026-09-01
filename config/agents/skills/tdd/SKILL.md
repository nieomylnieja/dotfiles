---
name: tdd
description: |
  Use only when the user explicitly requests test-driven development, test-first work,
  or a red-green-refactor workflow. Do not trigger for ordinary test or integration-test requests.
---

# Test-driven development

Use short red-green-refactor cycles.
Load the language and testing skills that apply to the codebase; they own test style and framework conventions.

## Cycle

1. Select one observable behavior from the agreed scope.
2. Write the smallest useful test for that behavior.
3. Run it and confirm that it fails for the expected reason.
4. Implement enough production code to make the test pass.
5. Run the focused test, then the relevant surrounding suite.
6. Refactor while the tests remain green.
7. Repeat for the next behavior.

Prefer a public or stable interface when it represents the behavior accurately.
Direct state checks, database assertions, characterization tests,
and test doubles can be valid evidence for the layer under test.
Follow existing project patterns rather than imposing a universal test shape.

If existing code already contains the fix,
create a characterization or regression test.
State that a pre-fix red run was not observed.
Do not revert a dirty shared worktree to force a red run.

## Boundaries

- Confirm only choices that remain materially ambiguous.
  An approved implementation plan does not need a second TDD plan approval.
- Keep each cycle small enough to diagnose.
  Use table-driven cases when project conventions make them clearer.
- Do not add speculative interfaces or mocks solely to satisfy a test.
- Record the failing and passing commands for the final verification report.
