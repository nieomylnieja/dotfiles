#!/bin/bash

main() {
  node="$1"
  sortBy="$2"

  case "${sortBy}" in
  cpu) sortBy=4 ;;
  mem) sortBy=5 ;;
  *) unset sortBy ;;
  esac

  top=$(kubectl get pod -o wide --all-namespaces | ag $node | awk '{print $2}' | tr '\n' '|')

  if [[ -z $sortBy ]]; then
    kubectl top pod --containers=true --all-namespaces | ag --nocolor "$top"
  else
    kubectl top pod --containers=true --all-namespaces | ag --nocolor "$top" | sort -h -k"$sortBy"
  fi
}

main "$@"
