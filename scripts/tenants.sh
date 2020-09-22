#!/bin/bash

MONGO_SECRETS_PATH="$HOME"/lerta/infrastructure/k8s/mongodb

main() {
  ctx=$(getKubeCtx)

  ext='.enc.json'
  regex='"password":'
  if [[ $env = 'production' ]]; then
    regex='"admin":'
    ext='.json'
  fi
	  
  pass=$(getSecret "$regex" "$ctx" "$ext")

  export tenantListJSON=$(getTenantInfo "$pass")
  shortName=`echo "$tenantListJSON" | jq -r '.[] | .shortName' | sed 's/[ \t]*$//' | fzf --preview 'echo "$tenantListJSON" | jq --arg short {} -C ".[] | select(.shortName == \\\$short)"'`
  echo "$tenantListJSON" | jq --arg short "$shortName" -r '.[] | select(.shortName == $short) | ._id' | tr -d '\n' | xclip -sel c
}

getKubeCtx() {
  env=`kubectl config current-context | awk -F "-" '{print $2}'`
  if [ $env == "dev" ]; then
    env="staging"
  fi
  echo $env
}

getSecret() {
  echo `sops -d $MONGO_SECRETS_PATH/$2/passwd$3 | grep $1 | awk -F " " '{print $2}' | sed -e 's/"//g'`
}

getTenantInfo() {
  echo `mongoexport --host="127.0.0.1:8102" --db=lerta --username=admin --password=$1 --authenticationDatabase "admin" --collection=tenant -q='{}' --fields='_id,name,shortName' --jsonArray --pretty --quiet | jq`
}

main $@
