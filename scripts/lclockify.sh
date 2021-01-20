#!/bin/bash

SCRIPT_PATH=$HOME/.dotfiles/scripts

read -r -d "\n" apiKey workspaceId userId <<<"$(sops --config "$SCRIPT_PATH"/.sops.yaml -d "$SCRIPT_PATH"/lclockify.secret.enc.json | jq -r '.apiKey, .workspaceId, .userId')"

generateSecret() {
  jq -n '{"apiKey":"","workspaceId":"","userId":""}' >>"$SCRIPT_PATH"/lmerge.secret.enc.json
  printf "Successfully generated 'lclockify.secret.enc.json'\nPlease fill the secret and encode it before running the script\n"
}

fetchWorkspaceIdAndUserId() {
  workspaceId=$(doRequest "workspaces" | jq -r '.[].id')
  userId=$(doRequest)
}

f_flag='false'

while getopts 'fg' flag; do
  case "${flag}" in
  g)
    generateSecret
    exit
    ;;
  f) f_flag='true' ;;
  *)
    echo "use either -h for help, -g to generate secrets or -f to fetch workspaceId and userId"
    exit
    ;;
  esac
done

main() {
  projects=$(doRequest "workspaces/$workspaceId/projects")
  tags=$(doRequest "workspaces/$workspaceId/tags")
  #  tasks=$(doRequest "projects/$projectId/tasks")
#  entries=$(doRequest "")
  echo "$projects" | jq -r '.[].name'
  echo "$tags" | jq -r '.[].name'

}

doRequest() {
  curl -H "content-type: application/json" -H "X-Api-Key: $apiKey" -X GET "https://api.clockify.me/api/v1/$1"
}

main "$@"
