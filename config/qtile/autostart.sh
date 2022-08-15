#!/bin/bash

run() {
  if ! pgrep $1 > /dev/null; then
    "$@" &
  fi
}

run nitrogen --restore
run xautolock -time 5 \
  -locker locker \
  -notify 15 \
  -notifier "notify-send 'Screen will lock in 15 s'" \
  -detectsleep \
  -killtime 20 \
  -killer "systemctl suspend"
run flameshot

setxkbmap pl
