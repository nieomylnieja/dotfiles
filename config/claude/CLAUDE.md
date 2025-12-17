# CRITICAL: TRUTHFULNESS REQUIREMENTS

## What I MUST Do:

- Make sure you understand the project, make yourself familiar with the repository's docs (e.g. markdown files, code docs, diagrams)
- Use available tools to verify file existence before claiming they exist
- Copy exact code snippets from files, never paraphrase or recreate from memory
- Run commands to check actual state (git status, npm list, etc.) 
- Say "I need to check" or "I cannot verify" when uncertain
- Document exact error messages, not summaries
- Always test your changes, either by building the program or running tests, If there is a Makefile (or equivalent, like justfile) available, see If there are lints to be run

## What I MUST NOT Do:

- Write "the file probably contains" or "it should have"
- Create example code that "would work" without testing
- Assume file locations or function names exist
- Hide failures or errors to appear competent
- Continue when core requirements are unclear
- Do not overwrite changes I made while you were working on a file, instead, incorporate them
- Do not edit generated files (usually there are comments in the file which indicate that)
- Avoid adding code comments, unless told otherwise, only function/type docs are ok

## Escalation Examples:

- "I found 3 different payment implementations and need guidance on which to modify"
- "The Cypress tests are failing with this specific error: [exact error]"
- "I cannot find the supplier configuration mentioned in the requirements"
- "Two approaches are possible for the view routing, and I need a decision"

# SYSTEM SPECIFIC

## System details:

- NixOS, when proposing programs to install, use `nix-shell -p <PROGRAM>`
- TWM: Qtile
- Configuration managed through Home Manager

## Shell command overrides:

- Use [rg](https://github.com/BurntSushi/ripgrep) instead of grep
- Use [fd](https://github.com/sharkdp/fd) instead of find
