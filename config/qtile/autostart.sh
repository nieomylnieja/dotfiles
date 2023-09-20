#!/bin/sh

run() {
  if ! pgrep "$1" > /dev/null; then
    "$@" &
  fi
}

wallpapers() {
  dir="${DOTFILES}/config/wallpapers"
  if ! test -n "$(find "$dir" -maxdepth 1 -name "*.jpg" -print -quit)" 2>/dev/null; then
    unzip -d "$dir" "$dir/wallpapers.zip"
  fi
  run feh --bg-fill --randomize "$dir/"*.jpg
}

run picom
run flameshot
wallpapers
