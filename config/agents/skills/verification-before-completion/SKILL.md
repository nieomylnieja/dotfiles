---
name: verification-before-completion
description: |
  Use when about to claim work is complete, fixed, or passing, before committing or creating PRs.
  Requires running verification commands and confirming output before making any success claims.
  Evidence before assertions, always.
---

# Verification Before Completion

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## Find the Project's Verification Commands First

**MANDATORY:** Before any verification, discover what this project uses.
Do not invent generic commands — use what the project defines.

### Where to look

1. **Task runners** (check for these files in the project root):
   - `justfile` / `.justfile` — run `just --list` to see available recipes
   - `Makefile` — run `make help` or scan targets with `grep '^[a-zA-Z]' Makefile`
   - `package.json` — check `scripts` section: `cat package.json | jq .scripts`

2. **CI workflows** — the most authoritative source of what "passing" means:
   - `.github/workflows/` — what does the CI run on PRs?
   - `.gitlab-ci.yml`, `.circleci/config.yml`, `Jenkinsfile`
   - The CI pipeline IS the definition of done. Mirror it locally.

### Priority order

```text
CI workflow steps > justfile/Makefile targets > package.json scripts > raw commands
```

Using raw commands (`go test ./...`, `npm test`) when a project defines
`just test` or `make test` is a verification failure —
the project wrapper may set required flags, env vars, or run additional checks.

## The Gate Function

BEFORE claiming any status or expressing satisfaction:

1. **DISCOVER**: Find the project's verification commands (see above)
2. **IDENTIFY**: What command proves this claim?
3. **RUN**: Execute the FULL command (fresh, complete)
4. **READ**: Full output, check exit code, count failures
5. **VERIFY**: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
6. **ONLY THEN**: Make the claim

Skip any step = lying, not verifying

## Common Failures

| Claim                 | Requires                        | Not Sufficient                 |
|-----------------------|---------------------------------|--------------------------------|
| Tests pass            | Test command output: 0 failures | Previous run, "should pass"    |
| Linter clean          | Linter output: 0 errors         | Partial check, extrapolation   |
| Build succeeds        | Build command: exit 0           | Linter passing, logs look good |
| Bug fixed             | Test original symptom: passes   | Code changed, assumed fixed    |
| Regression test works | Red-green cycle verified        | Test passes once               |
| Agent completed       | VCS diff shows changes          | Agent reports "success"        |
| Requirements met      | Line-by-line checklist          | Tests passing                  |

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- **Using raw commands when the project defines a task runner target**
- **Skipping CI workflow discovery — it defines what "passing" means**
- **ANY wording implying success without having run verification**

## Rationalization Prevention

| Excuse                                  | Reality                |
|-----------------------------------------|------------------------|
| "Should work now"                       | RUN the verification   |
| "I'm confident"                         | Confidence ≠ evidence  |
| "Just this once"                        | No exceptions          |
| "Linter passed"                         | Linter ≠ compiler      |
| "Agent said success"                    | Verify independently   |
| "I'm tired"                             | Exhaustion ≠ excuse    |
| "Partial check is enough"               | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter     |

## Key Patterns

### Tests

```text
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

### Regression tests (TDD Red-Green)

```text
✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

### Build

```text
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

### Requirements

```text
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

### Agent delegation

```text
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report
```

## Why This Matters

From 24 failure memories:

- your human partner said "I don't believe you" - trust broken
- Undefined functions shipped - would crash
- Missing requirements shipped - incomplete features
- Time wasted on false completion → redirect → rework
- Violates: "Honesty is a core value. If you lie, you'll be replaced."

## When To Apply

**ALWAYS before:**

- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Committing, PR creation, task completion
- Moving to next task
- Delegating to agents

**Rule applies to:**

- Exact phrases
- Paraphrases and synonyms
- Implications of success
- ANY communication suggesting completion/correctness

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.
