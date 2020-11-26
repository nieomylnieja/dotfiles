#!/bin/bash

SCRIPT_PATH=$HOME/.dotfiles/scripts

# this will stop the execution flow as soon as any cmd fails
set -o errtrace
set -o pipefail

help() {
  cat <<EOF

This script provides an automated way of merge requests creation both on gitlab and trello for lerta.
If you're running this script for the first time use '-g' flag:

  lmerge.sh -g

This will generate 'lmerge.secret.enc.json' and '.sops.yaml' if none already exists.
Otherwise existing files will be appended with new content, in which case you will need to resolve it by hand.

After generating the secret, you should fill it with required data:

  - trelloToken:  follow steps described in https://trello.com/app-key
  - trelloKey:    your key displayed at the top of app-key page
  - gitlabToken:  obtained from https://gitlab.com/-/profile/personal_access_tokens
  - trelloListId: "In progress" card id, this can be fetched together with gitlabUserId
  - gitlabUserId: your gitlab user id, this can fetched with:
    lmerge.sh -f <boarId> <username>

Target branch is determined as such:

  - -b flag is provided with <branchName> then use it
  - development is present in the tree, then use it, otherwise use master

Flags:

  - f, fetch trello "In progress" card id and gitlab user id
  - h, display help
  - b, provide custom defined target branch to merge into
  - g, generate secrets files

Authored by Mateusz Hawrus
EOF
}

generateSecret() {
  jq -n '{"trelloToken":"","trelloKey":"","trelloListId":"","gitlabToken":"","gitlabUserId":""}' >>"$SCRIPT_PATH"/lmerge.secret.enc.json
  echo '{"creation_rules":[{"path_regex":".*\\.enc\\.json","pgp":""}]}' | yq . -y >>"$SCRIPT_PATH"/.sops.yaml
  printf "Successfully generated 'lmerge.secret.enc.json' and '.sops.yaml'\nPlease fill the secret and encode it before running the script\n"
}

f_flag='false'
b_flag='false'

while getopts 'hgfb' flag; do
  case "${flag}" in
  h)
    help
    exit
    ;;
  g)
    generateSecret
    exit
    ;;
  f) f_flag='true' ;;
  b)
    if [ -z "$2" ]; then
      echo "Please provide target branch name you wish to merge into"
      exit
    fi
    b_flag='true'
    ;;
  *)
    echo "use either -h for help, -g to generate secrets or -f to fetch trello listId and gitlab userId"
    exit
    ;;
  esac
done

if [ ! -f "$SCRIPT_PATH"/lmerge.secret.enc.json ] || [ ! -f "$SCRIPT_PATH"/.sops.yaml ]; then
  printf "'lmerge.secret.enc.json' or '.sops.yaml' not found in %s\nFor more information run the script with '-h' flag\n" "$SCRIPT_PATH"
  exit
fi

main() {
  # read secrets and parse the git branch literal to extract git tag and task type
  read -r -d "\n" gitTag taskType _ <<<"$(git branch --show-current | sed 's/\//\n/g')"
  if [ -z "$gitTag" ] || [ -z "$taskType" ]; then
    echo "not a valid lerta git repo, expected structure: <id>/<task_type>/<description>"
    exit
  fi
  read -r -d "\n" trelloToken trelloKey trelloListId gitlabToken gitlabUserId <<<"$(sops -d "$SCRIPT_PATH"/lmerge.secret.enc.json | jq -r '.trelloToken, .trelloKey, .trelloListId, .gitlabToken, .gitlabUserId')"
  trelloBaseUrl="https://api.trello.com/1"
  trelloAuthPostfix="?key=$trelloKey&token=$trelloToken"

  # handle -f flag for fetching and displaying trello list id and gitlab user id
  if $f_flag; then
    if [ -z "$2" ]; then
      echo "Please provide trello board id which can be obtained from the url and gitlab username"
    else
      fetchListIdAndGitlabUserId "$trelloBaseUrl" "$trelloAuthPostfix" "$2" "$gitlabToken" "$3"
    fi
    exit
  fi

  # verification of the extracted secrets
  if [ -z "$trelloToken" ] || [ -z "$trelloKey" ] || [ -z "$trelloListId" ] || [ -z "$gitlabToken" ] || [ -z "$gitlabUserId" ]; then
    echo "please fill all the secrets in lmerge.secret.enc.json"
    exit
  fi

  # fetch trello card in order to create proper initial commit and push to origin
  trelloCard=$(curl -s "$trelloBaseUrl/lists/$trelloListId/cards$trelloAuthPostfix" | jq ".[] | select(.idShort == $gitTag)")
  if [ -z "$trelloCard" ]; then
    echo "failed to fetch trello card, make sure your card is placed in 'In progress' list and corresponds with branch the number in the branch name (first segment)"
    exit
  fi
  titleDescription=$(echo "$trelloCard" | jq -r .name | sed 's/|[0-9]*|//g' | xargs)
  if echo "$titleDescription" | grep -qe '::'; then
    titleDescription=$(echo "$titleDescription" | awk -F:: '{print $2}' | xargs)
  fi
  title="$taskType: $titleDescription"
  trelloCardUrl=$(echo "$trelloCard" | jq -r .url)

  # create initial commit and push to origin
  printf "%s\n\n%s\n" "$title" "$trelloCardUrl" >lmerge.tmp
  templateNumLines=0
  if [ -n "$(git config commit.template)" ]; then
    templateNumLines=$(wc <"$(git config commit.template)" -l)
    cat "$(git config commit.template)" >>lmerge.tmp
  fi
  vim lmerge.tmp
  # this will remove template if there was a single one
  head -n -"$templateNumLines" lmerge.tmp >lmerge.tmp.tmp
  mv lmerge.tmp.tmp lmerge.tmp
  if ! git commit -F lmerge.tmp; then
    echo "failed to commit"
    rm lmerge.tmp
    exit
  fi
  if ! git push origin "$(git branch --show-current)"; then
    echo "failed to push commit"
    rm lmerge.tmp
    exit
  fi

  # extract title from lmerge.tmp since it could've been changed
  read -r title <lmerge.tmp

  # fetch url encoded path of the project
  gitlabProjectPath=$(git config --get remote.origin.url | sed 's/\(.*:\|.git\)//g')
  gitlabProjectUrl=$(echo "$gitlabProjectPath" | sed 's/\//%2F/g')
  sourceBranch=$(git branch --show-current)
  targetBranch=$(determineTargetBranch "$2")
  # escape whitespace character for json and furthermore remove $' from the start and ' from the end
  description=$(printf "%q" "$(<lmerge.tmp)")
  description="${description:2:-1}"
  mergeRequestUrl=$(
    curl -s -H "Content-Type: application/json" -H "Private-Token: $gitlabToken" https://gitlab.com/api/v4/projects/"$gitlabProjectUrl"/merge_requests \
      -d '{"source_branch":"'"$sourceBranch"'","target_branch":"'"$targetBranch"'","title":"'"$title"'","assignee_id":'"$gitlabUserId"',"squash":true,"description":"'"$description"'"}' |
      jq -r .web_url
  )
  rm lmerge.tmp
  if [ -z "$mergeRequestUrl" ]; then
    echo "failed to create gitlab merge request"
    exit
  fi

  # proceed to attach merge request to trello card
  trelloCardId=$(echo "$trelloCard" | jq -r .id)
  attachmentName="[MR] $(echo "$gitlabProjectPath" | awk -F/ '{print $NF}')"
  statusCode=$(
    curl -o /dev/null -s -w "%{http_code}" -X POST -G \
      --data-urlencode "name=$attachmentName" \
      --data-urlencode "url=$mergeRequestUrl" \
      "$trelloBaseUrl/cards/$trelloCardId/attachments$trelloAuthPostfix"
  )
  if [ "$statusCode" != "200" ]; then
    printf "failed to attach merge request to trello card with code: %s" "$statusCode"
    exit
  fi

  printf "Successfully created:\n - merge request: %s\n - trello attachment: %s\n" "$mergeRequestUrl" "$trelloCardUrl"
}

determineTargetBranch() {
  if $b_flag; then
    if git branch | grep -qe "^.*\s$1$"; then
      echo "$1"
    else
      echo "target branch $1 does not exist"
      exit
    fi
  elif git branch | grep -qe '^.*\sdevelopment$'; then
    echo "development"
  else
    echo "master"
  fi
}

fetchListIdAndGitlabUserId() {
  listId=$(curl -s "$1/boards/$3/lists$2" | jq -r '.[] | select(.name == "In progress") | .id')
  userId=$(curl -s -H "PRIVATE-TOKEN: $4" https://gitlab.com/api/v4/users?username="$5" | jq -r '.[] | .id')
  printf "Trello listId: %s\nGitlab userId: %s\n" "$listId" "$userId"
}

main "$@"
