---
description: "Comprehensive PR review using specialized agents"
argument-hint: "[review-aspects]"
allowed-tools: ["Skill"]
---

# Comprehensive PR Review

**Review Aspects (optional):** "$ARGUMENTS"

Run [Skill("review-pr")](../skills/review-pr/SKILL.md)
passing any requested review aspects from `$ARGUMENTS`.

When the review is complete, use `AskUserQuestion` to determine if they want to
push the review to GitHub,
if so run [Skill("github-post-pr-review")](../skills/github-post-pr-review/SKILL.md).
