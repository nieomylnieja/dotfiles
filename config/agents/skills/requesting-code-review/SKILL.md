---
name: requesting-code-review
description: |
  Request an independent code review when the user asks for one.
  Also use after a risky or major change, before a merge or pull request,
  or when repository instructions require review.
  Do not trigger for every trivial edit.
---

# Requesting code review

Load [testing](../testing/SKILL.md) before preparing the review.
Dispatch independent, read-only reviewers for the requested scope:

- `standards-guardian` owns adherence to established code structure, patterns, and test conventions.
  Include it in every review, including focused reviews, documentation-only changes, and re-reviews.
- `code-reviewer` owns implementation defects in production and test code.
- `test-analyzer` owns test levels, coverage, usefulness, and assertion meaning.
  Include it when tests or meaningful behavior changed, even when test files are unchanged.

Apply explicit scope restrictions to every reviewer, including `standards-guardian`.
Run the reviewers independently with the same factual brief.
Queue required reviewers when capacity is full.
If delegation is unavailable, report the missing independent review and assess the permitted scope locally.
If `standards-guardian` cannot run, report standards coverage as incomplete.

## Review brief

Give the reviewer only the required context:

- the requirement and reason for the change.
- the exact files, diff, or commit range.
- project constraints and supported environments.
- known user changes that the reviewer must preserve.
- specific risk areas or questions.
- the required `testing` skill and the division of reviewer responsibilities.
- for `standards-guardian`, access to applicable rules, analogous code, and existing tests.

Do not ask the reviewer to edit files.
Do not bias it with the implementation discussion or your assessment of likely findings.

## Handle findings

Apply `feedback-reception` to every finding.
Verify the finding against the current code before changing anything.
Fix supported in-scope defects, reject false positives with evidence, and ask before expanding scope.
Run relevant checks after accepted changes.

If you are already a review subagent,
perform the assigned review instead of dispatching another reviewer.
