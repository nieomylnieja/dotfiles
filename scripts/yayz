#!/usr/bin/env bash

shopt -s lastpipe

if [[ -z $YAYZ ]]; then
  if command -v yay >/dev/null 2>&1; then
    YAYZ=yay
  elif ! command -v pacman >/dev/null 2>&1; then
    echo "Neither yay nor pacman found. Is this Arch?" >&2
    exit 1
  elif [[ $EUID -eq 0 ]] || [[ -f /usr/bin/msys-2.0.dll ]]; then
    YAYZ=pacman
  else
    YAYZ='sudo pacman'
  fi
fi

__yayz_help() {
  PROG=$(basename "$0")
  cat >&2 <<EOF
Usage: $PROG [OPTS]
A fzf terminal UI for yay or pacman.
sudo is invoked automatically, if needed.
Multiple packages can be selected.
The package manager can be changed with the environment variables: YAYZ
Keybindings:
  TAB                    Select
  Shift+TAB              Deselect
OPTS:
  -h, --help             Print this message
  All other options are passed to the package manager.
  Default: -S (install)
Examples:
  yayz -S --nocleanafter
  yayz -R
  YAYZ=yay yayz
EOF
  exit 1
}

__fzf_preview() {
  $YAYZ --color=always -Si "$1" | grep --color=never -v '^ '
}

__yayz_list() {
  $YAYZ --color=always -Sl | sed -e 's: :/:; s/ unknown-version//'
}

# main

while [[ -n $1 ]]; do
  case $1 in
  -h | --help)
    __yayz_help
    ;;
  __fzf_preview)
    shift
    __fzf_preview "$@"
    ;;
  *)
    break
    ;;
  esac
  shift
done

ARGS=("$@")

if [[ ${#ARGS[@]} -eq 0 ]]; then
  ARGS=("-S")
fi

declare -a PICKS
__yayz_list |
  fzf \
    --multi \
    --ansi \
    --preview="'${BASH_SOURCE[0]}' __fzf_preview {1}" |
  readarray -t PICKS

if [[ ${#PICKS[@]} -eq 0 ]]; then
  exit 0
fi

declare -a PKGS
for PICK in "${PICKS[@]}"; do
  PKGS+=("${PICK%% *}")
done

exec $YAYZ "${ARGS[@]}" "${PKGS[@]}"
