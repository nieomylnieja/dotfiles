#!/bin/bash

MONGO_SECRETS_PATH=~/lerta/infrastructure/k8s/mongodb/
EXT=.secret.enc.yaml

main() {
  env=$(getEnvironment)
  selected=`ls $MONGO_SECRETS_PATH$env | awk -F. '{ st = index($0,":"); if (substr($2,st+1)=="secret") {print $1}}' | fzf`

  pass=$(getSecret password $selected $env)
  user=$(getSecret username $selected $env)
  db=`echo $selected | sed -e "s/db$//"`

  mlerta $db $user $pass
}

getEnvironment() {
  env=`kubectl config current-context | awk -F "-" '{print $2}'`
  if [ $env == "dev" ]; then
    env="staging"
  fi
  echo $env
}

getSecret() {
  echo `sops -d $MONGO_SECRETS_PATH$3/$2$EXT | grep $1 | awk -F " " '{print $2}' | base64 -d`
}

mlerta() {
  kubectl exec -it lei-mongodb-0 -- mongo $1 -u $2 -p $3
}

main $@
