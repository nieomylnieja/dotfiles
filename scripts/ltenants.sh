#!/bin/bash

main() {
  ctx=$(getKubeCtx)

  pass=$(sops --config "$INFRA_PATH/k8s/mongodb/$ctx/.sops.yaml" -d "$INFRA_PATH/k8s/mongodb/$ctx/lertadb.secret.enc.yaml" | rg "password" | awk '{print $2}' | base64 -d)

  tenantListJSON=$(kubectl exec -n default lei-mongodb-0 -- mongo lerta -u lerta -p "$pass" --quiet --eval 'db.tenant.find({},{_id:1,name:1,shortName:1}).toArray()')
  shortName=$(echo "$tenantListJSON" | jq -r '.[] | .shortName' | sed 's/[ \t]*$//' | fzf --preview "echo '$tenantListJSON' | jq -C '.[] | select(.shortName == \"{}\")'")
  echo "$tenantListJSON" | jq -r '.[] | select(.shortName == "'"$shortName"'") | ._id' | tr -d '\n' | xclip -sel c
}

getKubeCtx() {
  env=$(kubectl config current-context | awk -F "-" '{print $2}')
  if [ "$env" == "dev" ]; then
    env="staging"
  fi
  echo $env
}

main "$@"
