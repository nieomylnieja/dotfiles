#!/usr/bin/env bash

if ! command -v hyprctl &> /dev/null; then
  echo >&2 "hyprctl not found. This script requires Hyprland."
  exit 1
fi

if ! command -v rofi &> /dev/null; then
  echo >&2 "rofi not found. Install with: nix-shell -p rofi-wayland"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo >&2 "jq not found. Install with: nix-shell -p jq"
  exit 1
fi

mapfile -t MONITORS < <(hyprctl monitors -j | jq -r '.[].name')

NUM_MONITORS=${#MONITORS[@]}

if [ "$NUM_MONITORS" -eq 0 ]; then
  echo >&2 "No monitors detected"
  exit 1
fi

TILES=()
COMMANDS=()

declare -i index=0
TILES["$index"]="Cancel"
COMMANDS["$index"]="true"
index+=1

for entry in $(seq 0 $((NUM_MONITORS - 1))); do
  TILES[index]="Only ${MONITORS[$entry]}"
  cmd="hyprctl keyword monitor ${MONITORS[$entry]},preferred,auto,1"
  for other in $(seq 0 $((NUM_MONITORS - 1))); do
    if [ "$entry" != "$other" ]; then
      cmd="$cmd && hyprctl keyword monitor ${MONITORS[$other]},disable"
    fi
  done
  COMMANDS[index]="$cmd"
  index+=1
done

for entry_a in $(seq 0 $((NUM_MONITORS - 1))); do
  for entry_b in $(seq 0 $((NUM_MONITORS - 1))); do
    if [ "$entry_a" != "$entry_b" ]; then
      TILES[index]="Extend ${MONITORS[$entry_a]} left of ${MONITORS[$entry_b]}"
      COMMANDS[index]="hyprctl keyword monitor ${MONITORS[$entry_a]},preferred,auto,1 && hyprctl keyword monitor ${MONITORS[$entry_b]},preferred,auto,1"
      index+=1

      TILES[index]="Extend ${MONITORS[$entry_a]} right of ${MONITORS[$entry_b]}"
      COMMANDS[index]="hyprctl keyword monitor ${MONITORS[$entry_a]},preferred,auto,1 && hyprctl keyword monitor ${MONITORS[$entry_b]},preferred,auto,1"
      index+=1

      TILES[index]="Mirror ${MONITORS[$entry_a]} to ${MONITORS[$entry_b]}"
      COMMANDS[index]="hyprctl keyword monitor ${MONITORS[$entry_a]},preferred,auto,1,mirror,${MONITORS[$entry_b]} && hyprctl keyword monitor ${MONITORS[$entry_b]},preferred,auto,1"
      index+=1
    fi
  done
done

function gen_entries() {
  for a in $(seq 0 $((${#TILES[@]} - 1))); do
    echo "$a" "${TILES[a]}"
  done
}

SEL=$(gen_entries | rofi -dmenu -p "Monitor Setup:" -a 0 -no-custom | awk '{print $1}')

if [ -n "$SEL" ]; then
  eval "${COMMANDS[$SEL]}"
  if command -v notify-send &> /dev/null; then
    notify-send "Monitor Setup" "${TILES[$SEL]}"
  fi
fi
