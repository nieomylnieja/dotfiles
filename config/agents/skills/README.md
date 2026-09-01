# Installed skills

This directory contains local skills and snapshots from external repositories.
Check the [skill lock file](../.skill-lock.json) before you edit a skill.
See [AUDIT.md](AUDIT.md) for the 2026-08-19 per-skill review and decisions.

## Ownership

A skill listed in the lock file is an upstream-managed snapshot.
`make update/skills` can replace local changes in those directories.
Make only necessary correctness or safety fixes in a managed snapshot,
and review the patch again after each update.

A skill without a lock entry is maintained in this repository.
Local skills can be revised directly,
but they still need focused evals and verification.

The update target changes external state and can replace tracked files.
Run it only when the user explicitly asks to update installed skills.

## Local routing policy

- Use passive web tools for public-page research and citations.
  Use `agent-browser` for interaction, JavaScript, login, or UI testing.
- Use a supplied local repository before `repo-analyzer` clones a remote one.
- Use `yt-dlp` only for requested video, audio, or metadata work.
  A video link alone does not authorize a download.
- Use `find-skills` for skills and plugin management for plugins.
- Use the Codex system `skill-creator` in Codex.
  The managed Anthropic skill with the same name is retained only as an
  upstream snapshot.

## Quarantine recommendations

These recommendations are not enforced by this README:

- `pdf`: retire and replace with an original skill.
  Its bundled license restricts retention, copying, modification,
  and distribution outside Anthropic Services.
- `improve-codebase-architecture`: keep automatic invocation disabled.
  It depends on missing skills and its report is not self-contained.
- `skill-creator`: do not invoke the managed copy in Codex because its name
  collides with the Codex system skill and its runner targets Claude.

The dated audit record is the canonical list of local patches carried in
managed snapshots. Review that list after every upstream skill update.
