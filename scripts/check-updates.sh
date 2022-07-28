#!/bin/bash

# checkupdates is available as part of https://archlinux.org/packages/community/x86_64/pacman-contrib/
# It does all `pacman -Syu` does, but just lists the packages.
updates="$(checkupdates)"

if [ -n "$updates" ]; then 
  dunstify \
    --block \
    --urgency normal \
    "Updates available" \
    "$updates"
fi

