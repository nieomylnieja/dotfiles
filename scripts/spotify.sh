#!/usr/bin/env bash

# Launch daemon if not yet launched.
if ! pgrep -c "spotifyd" > /dev/null; then
  spotifyd
fi

# Launch spotify-tui.
spt
