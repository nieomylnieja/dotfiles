#!/bin/bash

run() {
  if ! pgrep $1 > /dev/null; then
    "$@" &
  fi
}

run nitrogen --restore
run xautolock -time 5 -locker locker
