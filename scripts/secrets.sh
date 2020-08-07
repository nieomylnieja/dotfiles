#!/bin/bash

display_help() {
  echo "Usage: $0 [option...]"
  echo
  echo "   -d,              base64 decode the password"
  echo "   -h, --help       display this view"
  echo
  echo "Requires: fdfind, ripgrep, yq (based on jq), jq, fzf"
}

set -o pipefail

INFRA_PATH=~/lerta/infrastructure

d_flag='false'
u_flag='false'

while getopts 'hdu' flag; do
  case "${flag}" in
    h | --help) display_help 
      exit ;;
    d | --decode) d_flag='true' ;;
    u | --username) u_flag='true' ;;
    *) 
      exit ;;
  esac
done

main() {
  secret='pass(word)?'
  if $u_flag; then 
    secret='user(name)?'
  fi

  lpass "$secret"
}

lpass() {
  sopsed_passwd=`sops -d $INFRA_PATH/secrets/passwd.json`
  cd $INFRA_PATH/k8s
  list=`gpg -k | rg -B1 ultimate | head -n 1 | ( xargs rg --files-with-matches --sort path | awk '$0="s "$0' | cat -n ; echo "$(passwd_handler $sopsed_passwd)"  | awk '$0="p "$0' | cat -n ; )`
  selected=`echo "$list" | fzf --with-nth 3.. --preview 'echo {} | (read path; path=$(echo "$path" | awk '"'"'{print $3}'"'"') ; ext="${path##*.}" ;
      if [ "$ext" = "yaml" ] || [ "$ext" = "yml" ] ;
      then sops -d "$path" | yq . -C ;
      elif [ "$ext" = "json" ] ;
      then sops -d "$path" | jq -C ;
      elif [ -n "$ext" ] ;
      then echo "" ;
      else sops -d "$path" ;
      fi)'`
  idx="$((`echo "$selected" | awk '{print $1}'` - 1))"
  typ=`echo "$selected" | awk '{print $2}'`
  entry=`echo "$selected" | tr -s ' ' | cut -d ' ' -f3-`
  secret=''
  # Handle different custom files here. Typ is used to determine with wich one we're dealing.
  if [ "$typ" = "p" ]; then
    if $u_flag; then
      secret=`echo "$sopsed_passwd" | jq -r ".passwords[$idx] | .user" | tr -d "\n"`
    else
      secret=`echo "$sopsed_passwd" | jq -r ".passwords[$idx] | .password" | tr -d "\n"`
    fi
  else
    sopsed=`echo "$entry" | xargs sops -d`
    count=`echo "$sopsed" | rg -ci $1`
    if [[ "$count" -eq 1 ]]; then 
      secret=`echo "$sopsed" | rg -i '^.*'$1'"?:\s?"?(\S+)"?$' -r '$2' --trim | tr -d \"`
    elif [[ "$count" -gt 1 ]]; then
      secret=`echo "$sopsed" | fzf --tac --no-sort --phony | awk '{print $2}'  | xargs`
    else 
      echo "$sopsed"
    fi
  fi
  
  if [ -n "$secret" ] ; then
    if $d_flag && isBase64Encoded $secret ; then
      secret=`echo "$secret" | base64 -d`
    fi
  fi

  echo "$secret" | tr -d '\n' | xclip -sel clip

  cd - >/dev/null
}

isBase64Encoded() {
  if [[ `echo $1 | rg -ic '^([a-z0-9+/]{4})*([a-z0-9+/]{3}=|[a-z0-9+/]{2}==)?$'` -eq 1 ]]; then
    return 0
  else
    return 1
  fi
}

passwd_handler() {
  sops -d $INFRA_PATH/secrets/passwd.json | jq -r '.passwords[] | .name + " ("+ .description +")"'
}

main $@
