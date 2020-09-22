#!/bin/bash

LERTA_PROJECTS_PATH="$HOME"/lerta
PERSONAL_PROJECTS_PATH="$HOME/"myProjects

l_flag='false'
p_flag='false'

while getopts 'lp' flag; do
  case "${flag}" in
    l | --lerta) l_flag='true' ;;
    p | --personal) p_flag='true' ;;
    *) 
      exit ;;
  esac
done

main() {
  projectPath=''
  if "$p_flag"; then
    projectPath=$(fuzzy "$PERSONAL_PROJECTS_PATH")
  else
    projectPath=$(fuzzy "$LERTA_PROJECTS_PATH")
  fi
  cd "$projectPath"
}

fuzzy() {
  echo "$1"/`ls "$1" | fzf --preview "ls $1/{}"`
}

main $@
