#!/bin/bash

path=''

while getopts 'lpk' flag; do
  case "${flag}" in
  l) path="$HOME/lerta" ;;
  p) path="$HOME/myProjects" ;;
  k) path="$HOME/lerta/infrastructure/k8s" ;;
  *)
    exit
    ;;
  esac
done

main() {
  cd "$(fuzzy "$path")" || exit
}

fuzzy() {
  echo "$1"/"$(ls "$1" | fzf --preview "ls $1/{}")"
}

main "$@"
