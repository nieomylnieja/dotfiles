#!/usr/bin/env bash

set -eo pipefail

git for-each-ref \
  --format='%(refname),%(authorname)' \
  --sort=-committerdate |
  awk -F, '
    BEGIN {IGNORECASE=1}
    /hawrus/ && !/^refs\/stash/ {print $1}' |
  fzf --preview 'git log {}' |
  awk -F/ '
    /^refs\/remotes/ {printf "%s/%s",$(NF-1),$NF}
    !/^refs\/remotes/ {print $NF}' |
  xargs git checkout
