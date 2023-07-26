#!/usr/bin/env bash

LAYOUTS_DIR="$DOTFILES/config/xrandr"

selection=$(ls -1 $LAYOUTS_DIR |\
  cut -d '.' -f1 |\
  rofi -dmenu -i -width 6 -lines 4)

if [ -z "$selection" ]; then
  exit 0
fi

"$LAYOUTS_DIR/$selection.layout.sh"
nitrogen --restore &
