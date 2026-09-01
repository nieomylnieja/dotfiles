---
name: requesting-code-review
description: |
  Request an independent code review when the user asks for one.
  Also use after a risky or major change, before a merge or pull request,
  or when repository instructions require review.
  Do not trigger for every trivial edit.
---

# Requesting code review

Dispatch an independent, read-only `code-reviewer` agent.

## Review brief

Give the reviewer only the required context:

- the requirement and reason for the change.
- the exact files, diff, or commit range.
- project constraints and supported environments.
- known user changes that the reviewer must preserve.
- specific risk areas or questions.

Do not ask the reviewer to edit files.
Do not bias it with the implementation discussion or your assessment of likely findings.

## Handle findings

Apply `feedback-reception` to every finding.
Verify the finding against the current code before changing anything.
Fix supported in-scope defects, reject false positives with evidence, and ask before expanding scope.
Run relevant checks after accepted changes.

If you are already a review subagent,
perform the assigned review instead of dispatching another reviewer.
