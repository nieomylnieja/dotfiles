---
name: ste-writing
description: |
  Apply an STE-based writing baseline to every English user-facing response and every prose task.
  Invoke this skill before writing, rewriting, or reviewing documentation, READMEs, pull-request text,
  release notes, error messages, comments, tool descriptions, system prompts, or agent messages.
  Use its bundled linter for prose files and documentation-like final responses.
  Do not apply it to code or exact literals.
compatibility: Requires Nix. The first linter run can fetch a temporary Python 3 environment.
---

# STE writing

Use this skill to make prose direct, consistent, and easy to interpret.
It adapts the mechanical rules from ASD-STE100 Issue 9.
It does not certify ASD-STE100 compliance or verify factual content.

## Select a mode

- Use flavored mode for conversation and general prose.
- Use strict mode when a wrong reading has a cost.
  This includes procedures, runbooks, safety text, and error messages.
- Preserve a requested voice.
  Strict STE is not suitable for marketing or expressive writing.

## Protect the content

- Keep every fact, number, condition, exception, uncertainty, and scope limit.
- Keep precise technical terms, identifiers, commands, paths, units, quoted
  errors, safety wording, and required output formats unchanged.
- Prefer correctness to a shorter sentence or a lower score.
- Change only the text that a rule requires.

## Write the prose

- Use one name for one thing and one meaning for each word.
- Prefer short, common words when they preserve the technical meaning.
- Remove filler, empty hedges, and unsupported marketing claims.
- Use active voice and simple tenses.
  Use passive voice only when the actor is unknown or irrelevant.
- Express actions with verbs.
  Avoid nominalizations, phrasal verbs, and avoidable `-ing` main verbs.
- Put one idea in each sentence and one instruction in each step.
- In strict mode, limit instructions to 20 words and descriptions to 25 words.
- Put a condition before its command and separate them with a comma.
- Use necessary articles and do not use contractions or semicolons.
- Limit noun clusters to three words.
- Keep one topic and at most six sentences in each paragraph.
- Use numbered, imperative steps for procedures.
- Define an abbreviation once, then use it consistently.
- Use American spelling unless the user or project style guide says otherwise.

In strict mode, prefer `but` to `however`, `because` to causal `since`, `can`
to `may`, and `must` to `should` or `shall`.
Use `must` only for a real requirement.
Do not strengthen a recommendation.

For safety text, use `WARNING` for injury, `CAUTION` for damage, and `NOTE` for
information.
Never put an instruction in a `NOTE`.
Put safety text directly before the step that it protects.

## Review prose

For a review-only task, do not rewrite the source.
Report each issue in a `Rule | Original | Simplified` table.
Then identify text that you intentionally left unchanged and give the reason.

## Run the check

Apply the manual rules to routine conversation.
Run the bundled linter on every created or changed prose file.
Also lint a final response when the response serves as documentation.

Run flavored mode:

```sh
$DOTFILES/config/agents/skills/ste-writing/scripts/ste-lint.py \
  --fail-over 2.5 <file>
```

Run strict mode:

```sh
$DOTFILES/config/agents/skills/ste-writing/scripts/ste-lint.py \
  --strict --fail-over 1.5 <file>
```

Target `2.5` or fewer violations per 100 words in flavored mode.
Target `1.5` or fewer in strict mode.
Make at most two repair passes.
If the score remains high, preserve the content and report the score and cause.
Do not call prose clean without a linter run.
The linter checks mechanical form only and cannot prove accuracy.
It uses a conservative 20-word marker in both modes because it cannot reliably
classify a sentence as an instruction or a description.
Review a 21-to-25-word descriptive sentence manually before you change it.
The report counts em and en dashes as markers outside the score.
STE does not prohibit these characters, so do not present a marker as an STE
rule.
