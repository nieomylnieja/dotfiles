---
name: feedback-reception
description: |
  Use after receiving code-review or implementation feedback and before applying it.
  Verify the suggestion against the current code, requirements, and project constraints.
---

# Feedback reception

Treat feedback as a technical claim to evaluate.

## Process

1. Read the complete feedback and its surrounding discussion.
2. State the requested outcome when the meaning is not self-evident.
3. Verify the claim against the current code, tests, requirements, and supported environments.
4. Classify it as correct, partly correct, unclear, outdated, or incorrect.
5. Implement only the supported change and run relevant verification.

Continue with independent items when one item is unclear.
Stop only when the ambiguity changes other items
or needs a product or architecture decision.

## Response style

- Report the technical conclusion and evidence.
- Avoid praise, gratitude, and automatic agreement.
- If the feedback is correct, make the change or state the concrete next action.
- If it is partly correct, preserve the valid intent and explain the required adjustment.
- If it is incorrect, push back with code, tests, documentation, or compatibility evidence.
- If it is unclear, ask one focused question and name the blocked decision.
- If an earlier objection was wrong, state what the new evidence proved and correct course.

Do not implement feedback because of confidence scores, reviewer authority, or thread state alone.
Check whether the suggestion expands the user-approved scope before acting.

## Applying accepted feedback

Group related edits into a logical batch.
Test at the smallest useful boundary, then run the project-level checks required for the resulting claims.
Preserve deliberate user changes and comments unless the feedback explicitly covers them.
