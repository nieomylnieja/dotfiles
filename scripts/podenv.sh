#!/bin/bash

set -o pipefail

podRegexp="$1"

if test -z "$podRegexp"; then
  echo >&2 "empty pod regexp input"
  exit 1
fi

kubectl get pod |
  rg "$podRegexp" |
  fzf |
  head -n1 |
  awk "{print \$1;}" |
  tr -d "\n" |
  xargs -I {} kubectl exec {} -- env |
  rg -v _SERVICE |
  rg "${podRegexp^^}"
