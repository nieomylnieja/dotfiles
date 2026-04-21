---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

# Requesting Code Review

Dispatch the `code-reviewer` agent to catch issues before they cascade.
The reviewer gets precisely crafted context for evaluation — never your session's history.
This keeps the reviewer focused on the work product, not your thought process,
and preserves your own context for continued work.

**Core principle:** Review early, review often.

## When to Request Review

**Scope guard:**

- Use this skill from primary agents/orchestrators only.
- Do not invoke this skill from a subagent.
- If you are already the `code-reviewer` agent, perform the review directly.

**Mandatory:**

- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**

- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Determine scope:**

By default the reviewer inspects unstaged changes (`git diff`).
For committed work specify the files or commit range explicitly.

**2. Dispatch code-reviewer agent:**

Use the Agent tool with `subagent_type: "code-reviewer"` and a prompt that includes:

- What was implemented and why
- Which files / scope to focus on (or "review unstaged changes")
- Any relevant requirements or constraints

**3. Act on feedback:**

- Fix Critical issues (confidence 90-100) immediately
- Fix Important issues (confidence 80-89) before proceeding
- Push back if reviewer is wrong (with reasoning)

## Example

```text
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

[Dispatch code-reviewer agent]
  Prompt:
    Review the unstaged changes in git diff.
    I just added verifyIndex() and repairIndex() functions to handle
    4 types of index corruption. Focus on correctness and error handling.

[Agent returns]:
  Issues:
    Important [85]: Missing progress indicators for long-running repair
    Critical [92]: repairIndex() swallows errors from writeFile()
  Assessment: Fix before proceeding

You: [Fix the issues]
[Continue to Task 3]
```

## Integration with Workflows

**Subagent-Driven Development:**

- Review after EACH task
- Catch issues before they compound
- Fix before moving to next task

**Executing Plans:**

- Review after each batch (3 tasks)
- Get feedback, apply, continue

**Ad-Hoc Development:**

- Review before merge
- Review when stuck

## Red Flags

**Never:**

- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**

- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification
