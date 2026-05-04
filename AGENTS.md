# AGENTS.md

## Project Overview

This repository contains personal dotfiles for a NixOS workstation.
The root `flake.nix` defines two NixOS systems, `home` and `work`.
The primary daily target is `.#work`.

Important entrypoints:

- `config/nixos/work/configuration.nix` is the main NixOS system profile.
- `config/nixos/home/configuration.nix` is the secondary NixOS profile.
- `config/home-manager/home.nix` is the shared Home Manager user profile.
- `config/home-manager/flake.nix` supports standalone Home Manager use.
- `config/agents/` contains agent, skill, permission, and tool configuration.
- `config/nvim/`, `config/hypr/`, and `config/waybar/` contain interactive desktop
  configuration linked into the user environment.
- `scripts/llmcommit/` is a tracked Go helper module.

Home Manager activation creates symlinks from this repository into `$HOME`.
Changes under `config/home-manager/home.nix` can affect the interactive shell,
desktop session, editor setup, and agent configuration at the same time.

## Commands Agents Must Not Run by Default

Do not run system-changing, user-session-changing, install, update, or activation
commands unless the user explicitly asks for that exact operation.

Do not run these commands by default:

- `make rebuild`
- `sudo nixos-rebuild switch --flake .#work`
- `nixos-rebuild switch`
- `nixos-rebuild boot`
- `home-manager switch --flake ...`
- `make update`
- `make update/flakes`
- `make update/skills`
- `make update/agents`
- `nix flake update --commit-lock-file`
- `nix flake update --flake ./config/home-manager --commit-lock-file`
- `npx skills update`
- `make install/home-manager`
- `make install/nix`
- `make install/devbox`
- `make install/node`
- `make install/rust`
- `nix-channel`
- `nix-env`
- `rustup`
- `fnm install`
- `systemctl enable ...`
- `systemctl start ...`
- `systemctl --user enable ...`
- `systemctl --user start ...`
- `crontab ...`

If validation requires privileged access, package downloads, or writes outside
the repository, ask for approval and report the exact command and reason.

## Development Workflow

Use repository-defined targets for their documented purpose:

- `make update/flakes` updates both flake locks and commits lockfile changes.
- `make update/skills` updates installed skills through `npx skills update`.
- `make update/agents` syncs agent configuration into generated targets.

These targets are documented here so agents understand the project, not so they
run them automatically.

When changing NixOS or Home Manager configuration:

- Put host-specific system settings in `config/nixos/<host>/configuration.nix`.
- Put shared user packages, session variables, activation links, and user
  program settings in `config/home-manager/home.nix`.
- Keep `flake.nix` focused on wiring inputs, overlays, hosts, and Home Manager.
- Do not manually edit generated hardware configuration files unless the task
  explicitly requires hardware configuration changes.

When changing Go helper modules:

- This repository currently uses Go `1.26` in tracked Go modules.
- Run `go test ./...` from the module directory.
- Keep module-specific build commands inside the module directory.

## Working Tree Rules

The working tree may contain user changes.
Never revert, overwrite, reformat, or clean up unrelated files.
If user changes overlap with the task, inspect them and incorporate them rather
than replacing them.

Before finishing, report:

- files changed,
- verification commands run,
- exact failures if any command fails,
- commands skipped because they are unsafe or require explicit user approval.
