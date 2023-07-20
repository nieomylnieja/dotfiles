#!/usr/bin/env bash

PORT_CONFIG_FILE="$HOME/lerta/developer-tools/port-forwarder/configuration.local.json"

main() {
  localEnvFile=$(fd --no-ignore-vcs \\.local)
  currentPorts=$(rg -ie '(port?.*=.*|.*=.*localhost:)\d{4,}' "$localEnvFile")
  configEntries=$(echo "$currentPorts" | awk -F'[=:]' '{print $NF}' | xargs -I {} jq '.[] | select(.local == {} or .target == {})' "$PORT_CONFIG_FILE")
  selected=$(fzf -m <<<"$currentPorts")
  for s in $selected; do
    port=$(awk -F'[=:]' '{print $NF}' <<<"$s")
    swapped=$(jq <<<"$configEntries" "select(.target == $port or .local == $port) | if .target == $port then .local else .target end")
    if [ -z "$swapped" ]; then
      echo "couldn't find port mapping for port: $port"
      continue
    elif [[ "$(wc -l <<<"$swapped")" -gt 1 ]]; then
      conflicting=$(jq <<<"$configEntries" "select(.target == $port or .local == $port)")
      swappedName=$(echo "$conflicting" | jq -r '.name' | fzf --header="$s has ambiguous port mapping")
      swapped=$(jq <<<"$configEntries" "select(.name == \"$swappedName\") | if .target == $port then .local else .target end")
    fi
    sed -i "s/$port/$swapped/" "$localEnvFile"
  done
}

main "$@"
