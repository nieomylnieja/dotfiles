#!/usr/bin/env bash

commit=$(git fsck --lost-found |
  grep commit |
  cut -d ' ' -f3 |
  tac |
  fzf --no-sort --preview 'git show --color=always {1}')

if [[ "$commit" == "" ]]; then
  exit 0
fi

git update-ref refs/stash "$commit" --create-reflog -m "recovered stash"
