#!/usr/bin/env bash

set -eo pipefail

prefix=$(
  cat <<EOF | fzf
NOBL9_GO_
SLOCTL_
TERRAFORM_NOBL9_
EOF
)

config_path="$HOME/.config/nobl9/config.toml"

context=$(tomlq -r '.contexts | keys[]' "$config_path" |
  fzf --preview 'tomlq -t '"'"'.contexts | to_entries[] | select(.key == "{}") | .value'"'"' '"$config_path"' | bat -l toml --color=always')

declare -a envs
while read -r line; do
  if [[ "$line" == *oktaOrgURL* ]]; then
    key="OKTA_ORG_URL"
  else
    key=$(echo "$line" | cut -d'=' -f1 | sed 's/[A-Z]/_\l&/g' | tr '[:lower:]' '[:upper:]' | sed 's/ //')
  fi
  value=$(echo "$line" | cut -d'=' -f2- | sed 's/ //' | sed 's/"//g')
  envs+=("${prefix}${key}=$value")
done < <(tomlq -t '.contexts | to_entries[] | select(.key == "'"$context"'") | .value' "$config_path")

echo "${envs[*]}"
