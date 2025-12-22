#!/bin/sh
# shellcheck disable=2016

xidlehook \
  --detect-sleep \
  --not-when-audio \
  --timer 10 \
    'brightness set 50' \
    'brightness set 100' \
  --timer 10 \
    'brightness set 100; locker' \
    '' \
  --timer 3600 \
    'systemctl hibernate || systemctl suspend' \
    ''
