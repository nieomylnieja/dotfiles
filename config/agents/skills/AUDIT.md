# Skills audit

Audit date: 2026-08-19

## Evidence

Three independent audit lanes reviewed all 40 installed skills: workflow and Git,
language and writing, and tools and managed snapshots. Each lane checked trigger
scope, technical accuracy, safety, overlap, prose cost, and fit with repository
policy. The assignments covered 13 workflow skills, 13 language skills, and 14
tool or managed-snapshot skills. No skill appeared in more than one lane.

The style analysis used:

- 1,307 direct Codex prompts from 263 n9 and nobl9-go sessions;
- 1,516 direct prompts from relevant Claude project sessions;
- 1,516 authored GitHub reviews from `nobl9/n9` and `nobl9/nobl9-go`, with
  1,956 nonempty review bodies or inline comments.

The relevant Codex prompts had a median length of 12 words. The GitHub review
prose had a median length of 91 characters. Questions, concrete suggestions,
small suggestion blocks, and short inline comments were common. Repeated
corrections concerned generic PR testing claims, missing motivation, wrong
worktrees, premature review-thread replies, private-context leakage, missed
skills, scope drift, and completion claims without current evidence.

The GitHub corpus is a project-style signal. Review association does not prove
authorship of every discussion reply, so the audit did not copy surface habits
such as emoticons into agent policy.

Across the 40 main `SKILL.md` files, the audit reduced the word count from
48,307 to 25,924, a 46.3% reduction. It reduced `config/agents/AGENTS.md` from
909 to 753 words. The revisions kept operational constraints and moved optional
detail into references where it remained useful.

## Decisions

`Revised` means this audit materially changed the skill.
`Targeted` means the core workflow
already fit and received a narrow correction. `Quarantine` means the skill stayed
installed, but the audit recommends that automatic use stop until replacement or
repair.

<!-- markdownlint-disable MD013 -->

| Skill | Decision | Main reason or outcome |
| --- | --- | --- |
| `agent-browser` | Revised | Narrowed interactive-browser routing and classified `doctor` as state-changing. |
| `bats-testing-patterns` | Revised | Corrected temp scopes, shebangs, forwarding, fixtures, and failure handling. |
| `code-comments` | Targeted | Kept local-contract guidance and removed repeated or narrative comments. |
| `create-agentsmd` | Revised | Added hierarchy, preservation, verified-command, and mutation gates. |
| `create-github-pr` | Revised | Preserved exact base/head, removed duplicate confirmation, and blocked stale metadata. |
| `css` | Revised | Replaced three universal rules with project, accessibility, and rendering checks. |
| `excalidraw-diagram-generator` | Revised | Replaced stale library claims and repeated examples with verified templates, helpers, and fallback rules. |
| `feedback-reception` | Revised | Replaced canned acceptance with verify, accept, reject, or clarify decisions. |
| `find-skills` | Revised | Made discovery read-only by default and added supply-chain inspection. |
| `gif-creator` | Targeted | Corrected the Manim API and added historical visual-regression evals. |
| `git-commit` | Revised | Preserved staged scope and matched message conventions per repository. |
| `git-worktrees` | Revised | Removed resets, setup downloads, and hidden-file copying; added exact commits. |
| `github-post-pr-review` | Revised | Added exact base/head and diff-position preflight before pending-review writes. |
| `github-pr-comments` | Revised | Added complete thread identity and kept addressing separate from resolution. |
| `golang` | Targeted | Removed provider-specific execution syntax and reduced duplicated core advice. |
| `golang-comments` | Revised | Separated Go syntax rules from repository documentation policy. |
| `golang-performance` | Revised | Removed universal allocation, pooling, transport, and benchmark claims. |
| `golang-testing` | Revised | Uses the owning module version, project-first helpers, and safe parallelism. |
| `grafana-dashboards` | Revised | Replaced legacy models and missing assets with version, query, round-trip, and API-write gates. |
| `html-to-markdown` | Revised | Narrowed routing and added HTTP, size, timeout, redirect, and address checks. |
| `improve-codebase-architecture` | Quarantine | Missing dependencies, unsafe report behavior, and imposed vocabulary block use. |
| `markdown` | Revised | Removed the copied style specification and kept repository-specific decisions. |
| `notebooklm` | Revised | Narrowed triggering and added version, login, profile, and mutation gates. |
| `pdf` | Quarantine | The bundled license is incompatible with this tracked Codex configuration. |
| `pr-comment-audit` | Revised | Defaults to report-only and requires current pushed code and full thread context. |
| `pr-description` | Revised | Keeps supported motivation and change-specific Testing while removing repetition. |
| `re-review-pr` | Revised | Persists only filtered findings at the exact current base and head. |
| `repo-analyzer` | Revised | Uses local checkouts first and fails closed on clone or revision errors. |
| `requesting-code-review` | Revised | Narrowed its trigger and routes findings through evidence-based feedback handling. |
| `review-pr` | Revised | Uses exact PR metadata and only read-only specialist agents. |
| `shell` | Revised | Split Bash from POSIX rules and fixed fatal, heredoc, cleanup, and NixOS guidance. |
| `skill-creator` | Quarantine | Its name collides with the Codex system skill and its runner targets Claude. |
| `ste-writing` | Revised | Grouped review findings and made its linter failures and paths precise. |
| `supabase-postgres-best-practices` | Revised | Matched the trigger to bundled coverage and corrected its version. |
| `tdd` | Revised | Triggers only on explicit test-first or red-green-refactor intent. |
| `tui-development` | Targeted | Added PTY-first verification and explicit GUI authorization. |
| `verification-before-completion` | Revised | Maps claims to current, safe, relevant evidence without destructive reversion. |
| `vhs-gif-creator` | Targeted | Moved persistence detail behind progressive disclosure. |
| `writing-docs` | Targeted | Added source-of-truth, generated-file, primary-link, and command-evidence checks. |
| `yt-dlp` | Revised | Requires explicit operation intent, matches tested single-item wrappers, and avoids default sidecars. |

<!-- markdownlint-enable MD013 -->

## Adversarial review

Independent reviewers checked specification coverage, implementation, tests,
documentation, comments, and failure handling. Their challenges led to these
repairs:

- removed secret-copying and branch-attached worktree paths;
- preserved command errors instead of mapping them to normal absence;
- validated exact PR base, head, diff positions, review owner, and write outcome;
- reserved private review files and handled clone destination races;
- redacted signed URLs and blocked non-public redirect targets; and
- required downloaded output files to exist before reporting success.

The final code review found no remaining Critical or Important defect.

## Managed snapshot patches

`make update/skills` can overwrite these local corrections:

- `agent-browser`: narrow routing and treat `doctor` as state-changing.
- `create-agentsmd`: replace the generic template with a verified,
  hierarchy-aware repository workflow.
- `excalidraw-diagram-generator`: remove stale library claims and route to
  verified templates and helpers.
- `grafana-dashboards`: replace legacy examples and missing assets with
  version-aware query and round-trip checks.
- `notebooklm`: replace conflicting activation and autonomy text with explicit
  version, authentication, profile, and mutation boundaries.
- `supabase-postgres-best-practices`: correct version metadata and trigger scope.
- `yt-dlp`: require explicit intent and match the tested single-item wrappers.

## Policy decisions

- Keep the 1% invocation rule, but apply it to a skill's stated scope. Incidental
  words or chat formatting do not trigger file-oriented skills.
- Challenge decisions when evidence or constraints warrant it. Mandatory
  disagreement creates noise and does not improve truthfulness.
- Treat an explicit commit, PR creation, or review-publication request as the
  required authority for that named action. Ask only for a missing material
  choice or a separate action, such as committing uncommitted work.
- Match verification to the claim. A prose change needs prose checks; a runtime
  behavior claim needs a behavior test.
- Keep managed-snapshot patches focused and record them in this audit.
  An update can overwrite them.

## Deferred decisions

No skill was deleted. Replacing `pdf`, disabling or replacing
`improve-codebase-architecture`, and renaming or removing the managed
`skill-creator` change installed capabilities and need an explicit user decision.
