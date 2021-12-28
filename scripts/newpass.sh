#!/bin/bash

set -e

function read_non_empty() {
  local input
  read -r input
  if test -z "$input"; then
    echo >&2 "empty input"
    exit 1
  fi
  echo "$input"
}

function main() {
  dir="$(fd -t d -H --base-directory=$HOME/.password-store | awk '{print}; END { print "New" }' | fzf)"

  if [ $dir == "New" ]; then
    echo -n "Pass a full path, a new dir will be created: "
    path="$(read_non_empty)"
  else
    echo -n "Pass a relative path to $dir dir: "
    path="$dir/$(read_non_empty)"
  fi

  echo -n "Provide a username if applicable: "
  read -r username

  local pass="$(apg -n 1 -m 16 -x 16 -a 1)"

  if [ -z "$username" ]; then
    echo "$pass" | pass insert -m "$path"
  else
    cat <<EOF | pass insert -m "$path"
$pass
---
username: $username
url: $(basename "$path")
EOF
  fi

  echo "Created pass $path entry" && exit 0

  pass show -c $path
}

main "$@"
