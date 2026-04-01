#!/bin/bash

# Check if gopls is installed and available in PATH

if command -v gopls &>/dev/null; then
  # gopls is installed, exit silently
  exit 0
fi

# Check if go is installed (required to install gopls)
if ! command -v go &>/dev/null; then
  echo "[gopls] Go is not installed. Please install Go first from https://go.dev/dl/"
  echo "        Then run: go install golang.org/x/tools/gopls@latest"
  exit 0
fi

# Go is installed but gopls is not - install it
echo "[gopls] Installing gopls..."
go install golang.org/x/tools/gopls@latest

if command -v gopls &>/dev/null; then
  echo "[gopls] Installed successfully"
else
  # gopls might be installed but not in PATH (common issue with ~/go/bin)
  if [ -f "$HOME/go/bin/gopls" ]; then
    echo "[gopls] Installed to ~/go/bin/gopls"
    echo "[gopls] Add ~/go/bin to your PATH:"
    echo "        export PATH=\"\$PATH:\$HOME/go/bin\""
  else
    echo "[gopls] Failed to install. Please run manually:"
    echo "        go install golang.org/x/tools/gopls@latest"
  fi
fi

exit 0
