#!/bin/bash

SCRIPT_PATH=$DOTFILES/scripts

read -r -d '\n' email token domain user_id jira_project <<<"\
  $(sops --config "$SCRIPT_PATH/.sops.yaml" -d "$SCRIPT_PATH/atlassian-secrets.enc.json" |
  jq -r '.email, .token, .domain, .user_id, .jira_project')"

curl -s "$domain/rest/api/2/search?jql=assignee=$user_id+and+project=$jira_project+and+statusCategory=indeterminate" --user "$email:$token" |
  jq -r '.issues[] | (.key) + "-" + (.fields.summary | ascii_downcase | .)' |
  sed 's/ /-/g' |
  sed -E 's/-{2,}/-/g' |
  sed 's/-*$//' |
  fzf |
  xargs git checkout -b
