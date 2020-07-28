#!/bin/bash

help() {
cat << EOF

This script serves as a wrapper around httpie.
It sets both X-Tenant and X-User-Data settings.
If the header is already there, then it proxies the command.
If the header is not provided, then it defaults using envs:
  - X-Tenant --> DEFAULT_TENANT_ID
  - X-User-Data --> DEFAULT_USERDATA_OBJECT
Note that default user should belong to default tenant!
If -u flag is provided It will present you with a fuzzyfind list of users
for a given tenant. Here you can provide it with any valid tenant identifier:
  - name
  - shortName
  - tenantId

Usage: $0 [option...]"

  -u,      select user for given x-tenant
  -h,      display this view

Requires: ripgrep, yq, jq, fzf

EOF
}

INFRA_PATH=~/lerta/infrastructure

u_flag='false'
x_tenant='false'
x_user_data='false'

if [[ $(echo "$@" | rg "\s-u\s*") ]]; then
  u_flag='true'
fi
if [[ $(echo "$@" | rg -i "\sx-tenant:\s*") ]]; then
  x_tenant='true'
fi
if [[ $(echo "$@" | rg -i "\sx-user-data:\s*") ]]; then
  x_user_data='true'
fi

if [[ $(echo "$@" | rg "\s-h\s*") ]]; then
  help
  exit 1
fi

for arg do
  shift
  [ "$arg" = "-u" ] || [ "$arg" = "-h" ] && continue
  set -- "$@" "$arg"
done

main() {
  pass=`sops -d $INFRA_PATH/k8s/mongodb/staging/lertadb.secret.enc.yaml | rg "password" | awk '{print $2}' | base64 -d`
  if $x_tenant && $x_user_data ; then 
    http "$@"
  elif $x_tenant ; then 
    userDataObject=$(setUserDataObject "$@")
    http "$@" x-user-data:"$userDataObject"
  elif $x_user_data ; then
    tenantId=$(setTenantId "$@")
    http "$@" x-tenant:"$tenantId"
  else
    tenantId=$(setTenantId "$@")
    userDataObject=$(setUserDataObject "$@")
    http "$@" x-user-data:"$userDataObject" x-tenant:"$tenantId"
  fi
}

setTenantId() {
  tenantKey=`echo "$@" | tr " " "\n" | rg "x-tenant" | cut -d ':' -f2- | tr -d "\n"`
  if $u_flag && [[ $(echo "$tenantKey" | rg '^[a-z]+-[a-z]+$') ]]; then
    echo `mongo lerta --host="127.0.0.1:8102" -u lerta -p "$pass" --quiet --eval 'db.tenant.find({$or: [{name:"'"$tenantKey"'"}, {shortName:"'"$tenantKey"'"}, {_id:"'"$tenantKey"'"}]})' | jq -r '._id'`
  else 
    echo "$DEFAULT_TENANT_ID"
  fi
}

setUserDataObject() {
  userDataObject=`echo "$@" | tr " " "\n" | rg "x-user-data" | cut -d ':' -f2-`
  if [[ -z "$userDataObject" ]]; then
    if $u_flag ; then 
      users=`mongo lerta --host="127.0.0.1:8102" -u lerta -p "$pass" --quiet --eval "printjson(db.user.find({\"tenantId\":\"$tenantId\"}).toArray())" | yq r - -j | jq`
      selected=`echo "$users" | jq -r '.[] | .email' | fzf`
      mapfile -t data < <(echo "$users" | jq -r ".[] | select(.email == \"$selected\") | ._id, .externalId, .role" | cut -d '"' -f2)
      echo "{\"id\":\"${data[0]}\", \"externalId\":\"${data[1]}\", \"role\":\"${data[2]}\"}"
    else
      echo "$DEFAULT_USERDATA_OBJECT"
    fi
  else
    echo "$userDataObject"
  fi
}

main $@
