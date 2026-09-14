---
name: grill
description: >-
  Grill the user about a plan, decision, or idea. Use when the user asks to
  stress-test their thinking or expresses uncertainty about implementation
  choices that materially affect the result. For factual confusion alone,
  explain or investigate first.
---

# Grill

Interview the user relentlessly until you reach a shared understanding.
Map this as a **design tree**: every decision branches into the decisions that hang off it.

For an explicit interview request, explore the plan, decision, or idea the user names.
For automatic invocation, limit the tree to unresolved choices
that materially affect the requested implementation.
Explain relevant facts before asking the user to choose.
Continue authorized work that does not depend on those choices.

Work the tree in **rounds**.
The **frontier** is every decision whose prerequisites are already settled:
the questions you can ask _now_ without guessing at answers you haven't heard yet.
Ask the whole frontier in one round: number each question and give your recommended answer.
Then wait for the user's answers before the next round.

Format a round like so:

```md
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Each round the user answers reshapes the tree:
settled decisions push the frontier outward and unblock questions that depended on them.
Recompute the frontier and ask the next round.
A question whose answer depends on another question still open in this round
belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's.
When a frontier question needs a fact from the environment (filesystem, tools, etc.),
dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself.
Don't block on it: a running exploration is an unsettled prerequisite,
so only the questions downstream of it wait for the sub-agent to report;
ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty within that scope:
the user has settled each material choice and its dependent decisions.
Summarize the decisions and their consequences.
If implementation is already authorized, resume once the user settles the blocking choices.
For an interview-only request, wait for the user to request implementation.
