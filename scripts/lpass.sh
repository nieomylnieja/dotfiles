#!/bin/bash

INFRA_PATH=~/lerta/infrastructure

main() {
  sopsed=$(sops -d $INFRA_PATH/secrets/passwd.json)
  idx=$(echo "$sopsed" | jq -r '.passwords[] | .name + " ("+ .description +")"' | cat -n | fzf --with-nth 2.. | awk '{print $1}')
  echo "$sopsed" | jq -r ".passwords[$idx] | .password" | tr -d '\n' | xclip -sel clip
}

main "$@"
