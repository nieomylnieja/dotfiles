#!/bin/bash

run {
  if ! pgrep $1 > /dev/null; then
    $@&
  fi
}

nitrogen --restore &
xautolock -time 5 -locker locker &
