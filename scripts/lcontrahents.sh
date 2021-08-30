#!/bin/bash

main() {
  ctx=$(getKubeCtx)

  pass=$(sops -d "$INFRA_PATH/k8s/mongodb/$ctx/capacityMarketOperations.secret.enc.yaml" | rg "password" | awk '{print $2}' | base64 -d)

  contrahentsListJSON=$(kubectl exec lei-mongodb-0 -- mongo capacityMarketOperations -u lerta -p "$pass" --quiet --eval 'db.contrahent.find({},{_id:1,name:1,shortName:1}).toArray()' | sed -E 's/(.*)(ObjectId\()(.*)(\)(.*))/\1\3\5/')
  shortName=$(echo "$contrahentsListJSON" | jq -r '.[] | .shortName' | sed 's/[ \t]*$//' | fzf --preview "echo '$contrahentsListJSON' | jq -C '.[] | select(.shortName == \"{}\")'")
  echo "$contrahentsListJSON" | jq -r '.[] | select(.shortName == "'"$shortName"'") | ._id' | tr -d '\n' | xclip -sel c
}

getKubeCtx() {
  env=$(kubectl config current-context | awk -F "-" '{print $2}')
  if [ "$env" == "dev" ]; then
    env="staging"
  fi
  echo $env
}

main "$@"
