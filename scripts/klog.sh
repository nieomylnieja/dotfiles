#!/bin/bash
set -euo pipefail

main() {
  kpod=$(kubectl get pod | fzf | head -n1 | awk '{print $1}' | tr -d '\n')
  containers=$(kubectl get -o json pod "$kpod" | rg -v ^HEAD | jq -r '.spec.containers | .[] | .name')
  container=$(echo "$containers" | head -n 1)
  if [[ $(echo "$containers" | wc -l) -gt 1 ]]; then
    container=$(echo "$containers" | fzf)
  fi
  kubectl logs -f "$@" "$kpod" -c "$container"
}

main "$@"
