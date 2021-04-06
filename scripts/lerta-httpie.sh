#!/bin/bash

set -o errtrace
set -eo pipefail

help() {
  cat <<EOF

This script serves as a wrapper around httpie.
It sets both X-Tenant and X-User-Data settings.
If the header is already there, then it proxies the command.
If the header is not provided, then it defaults using envs:
  - X-Tenant --> DEFAULT_TENANT_ID
  - X-User-Data --> DEFAULT_USERDATA_OBJECT
Note that default user should belong to default tenant!
If -u flag is provided It will present you with a fuzzy-find list of users
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

internal='false'
noc_request='false'
u_flag='false'
x_tenant='false'
x_user_data='false'
x_origin_system='false'

if [[ $(echo "$@" | rg "\s-u\s*") ]]; then
  u_flag='true'
fi
if [[ $(echo "$@" | rg "\s--internal\s*") ]]; then
  internal='true'
fi
if [[ $(echo "$@" | rg "\s--noc\s*") ]]; then
  noc_request='true'
fi
if [[ $(echo "$@" | rg -i "\sx-tenant:\s*") ]]; then
  x_tenant='true'
fi
if [[ $(echo "$@" | rg -i "\sx-user-data:\s*") ]]; then
  x_user_data='true'
fi
if [[ $(echo "$@" | rg -i "\sx-origin-system:\s*") ]]; then
  x_origin_system='true'
fi

if [[ $(echo "$@" | rg "\s-h\s*") ]]; then
  help
  exit 1
fi

for arg; do
  shift
  [ "$arg" = "-u" ] || [ "$arg" = "-h" ] || [ "$arg" = "--internal" ] || [ "$arg" = "--noc" ] && continue
  set -- "$@" "$arg"
done

main() {
  args=("$@")
  # set X-Tenant default header if not present
  if ! $x_tenant; then
    args+=("x-tenant:$DEFAULT_TENANT_ID")
  fi
  if $noc_request; then
    args+=("x-tenant:noc")
    args+=("x-origin-system:noc")
  fi
  if ! $internal && ! $noc_request; then
    if ! $x_origin_system; then
      args+=("x-origin-system:lei")
    fi
    # set X-User-Data and corresponding X-User header
    # if not present use the default
    # choose one from the list if u_flag was provided
    if ! $x_user_data && ! $u_flag; then
      args+=("x-user-data:$DEFAULT_USERDATA_OBJECT")
      args+=("x-user:$(echo "$DEFAULT_USERDATA_OBJECT" | jq -j .id)")
    elif $u_flag; then
      x_user_data_header=$(setUserDataObject "$@")
      args+=("x-user-data:$x_user_data_header")
      args+=("x-user:$(echo "$x_user_data_header" | jq -rj .id)")
    fi
  fi
  # run http with all of the provided arguments
  http "${args[@]}"
}

setUserDataObject() {
  pass=$(sops -d $INFRA_PATH/k8s/mongodb/staging/lertadb.secret.enc.yaml | rg "password" | awk '{print $2}' | base64 -d)
  tenantId=$(getTenantId "$@")
  users=$(kubectl exec lei-mongodb-0 -- mongo lerta -u lerta -p "$pass" --quiet --eval "printjson(db.user.find({\"tenantId\":\"$tenantId\"}).toArray())" | sed -E 's/(.*)(ObjectId\()(.*)(\)(.*))/\1\3\5/' | jq)
  selected=$(echo "$users" | jq -r '.[] | .email + " (" + .role + ")"' | fzf | awk '{print $1}')
  mapfile -t data < <(echo "$users" | jq -r ".[] | select(.email == \"$selected\") | ._id, .externalId, .role" | cut -d '"' -f2)
  userDataObject="{\"id\":\"${data[0]}\", \"externalId\":\"${data[1]}\", \"role\":\"${data[2]}\"}"
  echo "$userDataObject"
}

getTenantId() {
  tenantKey=$(echo "$@" | tr " " "\n" | rg "x-tenant" | cut -d ':' -f2- | tr -d "\n")
  if $u_flag && [[ $(echo "$tenantKey" | rg '^[a-z]+-[a-z]+$') ]]; then
    mongo lerta --host="127.0.0.1:8102" -u lerta -p "$pass" --quiet --eval 'db.tenant.find({$or: [{name:"'"$tenantKey"'"}, {shortName:"'"$tenantKey"'"}, {_id:"'"$tenantKey"'"}]})' | jq -r '._id'
  elif $x_tenant; then
    echo "$tenantKey"
  else
    echo "$DEFAULT_TENANT_ID"
  fi
}

main "$@"
