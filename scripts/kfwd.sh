#!/bin/bash

set -o errtrace
set -o pipefail

FORWARDER_PATH="$HOME/lerta/developer-tools/port-forwarder/forwarder.py"

main() {
  target=$(kubectl get svc,pod --no-headers -o name | fzf)
  case "$target" in
  service*) __fwdService "$target" ;;
  pod*) __fwdPod "$target" ;;
  esac
}

__kfwd() {
  target="$1"
  targetPort=$(echo "$2" | cut -d'/' -f1)
  localPort=$(rg <"$FORWARDER_PATH" \""$(echo "$target" | cut -d'/' -f2)"\" | awk -F',' '{print $2}' | xargs)
  if test -z "$localPort"; then
    localPort="$targetPort"
  fi
  echo "kubectl port-forward $target $localPort:$targetPort"
  kubectl port-forward "$target" "$localPort:$targetPort"
}

__fwdService() {
  target="$1"
  targetPort=$(__getServicePorts "$1")
  __kfwd "$target" "$targetPort"
}

__fwdPod() {
  target="$1"
  targetPort=$(__getPodPorts)
  __kfwd "$target" "$targetPort"
}

__getServicePorts() {
  target="$1"
  port=$(kubectl get "$target" --no-headers | awk '{print $5}')
  IFS=',' read -ra portsArr <<<"$port"
  if ((${#portsArr[@]} > 1)); then
    port=$(echo "$port" | sed 's/,/\n/g' | fzf -d',')
  fi
  echo "$port"
}

__getPodPorts() {
  kubectl get pod smart-plug-controller-54949fbd5d-fksp2 -o json | jq .spec.containers[].ports[].containerPort | fzf
}

main "$@"
