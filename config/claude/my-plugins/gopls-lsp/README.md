# gopls LSP Plugin

Go language server (gopls) integration for Claude Code, providing real-time code intelligence while working with Go codebases.

## Features

- **Instant diagnostics**: See errors and warnings immediately after each edit
- **Code navigation**: Go to definition, find references, hover information
- **Language awareness**: Type information and documentation for Go symbols
- **Enhanced completion**: Deep completion with placeholders and documentation
- **Static analysis**: Enabled staticcheck and common analyzers (unused params, shadow variables)
- **Code formatting**: gofumpt integration for consistent formatting

## Prerequisites

You must have `gopls` installed on your system:

```bash
# Install gopls
go install golang.org/x/tools/gopls@latest

# Verify installation
gopls version
```

## Installation

This plugin can be installed via a marketplace or loaded directly:

```bash
# Load for a single session
claude --plugin-dir /home/mh/.dotfiles/config/claude/gopls-lsp

# Or add to a marketplace for permanent installation
```

## Configuration

The plugin uses these gopls settings by default:

- `usePlaceholders`: Show parameter placeholders in completions
- `completionDocumentation`: Include documentation in completions
- `deepCompletion`: Enable deep completion for better suggestions
- `staticcheck`: Enable staticcheck analyzer
- `gofumpt`: Use gofumpt for formatting (stricter than gofmt)
- Analyzers: `unusedparams`, `shadow`

You can customize these settings by modifying `.lsp.json`.

## Usage

Once installed, gopls will automatically:

1. Start when Claude opens Go files (`.go` extension)
2. Provide diagnostics as you or Claude edit code
3. Enable code navigation (go to definition, find references)
4. Show type information and documentation on hover

Claude will see all diagnostics immediately and can fix issues in real-time.

## Troubleshooting

**"Executable not found in $PATH"**:
- Make sure `gopls` is installed: `go install golang.org/x/tools/gopls@latest`
- Verify it's in your PATH: `which gopls`
- On NixOS, you may need: `nix-shell -p gopls`

**LSP server not starting**:
- Check Claude Code debug output: `claude --debug`
- Verify gopls works independently: `gopls version`
- Check the LSP logs in the `/plugin` Errors tab

## Version

1.0.0
