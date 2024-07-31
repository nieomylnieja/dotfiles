#!/usr/bin/env bash

set -e

environment=$(gh api /repos/nobl9/n9/environments --jq .environments[].name | fzf)

if [[ $(git -C ~/nobl9/n9 ls-remote --heads origin "refs/heads/${environment}" | wc -l) == 0 ]]; then
  echo "Branch ${environment} does not exist"
fi

latestRun=$(gh -R nobl9/n9 run list --branch="$environment" --json name,createdAt,status,databaseId --jq .[0])

name=$(jq -r .name <<<"$latestRun")
createdAt=$(jq -r .createdAt <<<"$latestRun")
status=$(jq -r .status <<<"$latestRun")
id=$(jq -r .databaseId <<<"$latestRun")

if [[ $status == "completed" ]]; then
  notify-send \
    "Deployment to ${environment} was already completed!" \
    "${name}\nStarted at ${createdAt}\nStatus: ${status}"
fi

gh -R nobl9/n9 run watch --interval=10 "$id"

status=$(gh -R nobl9/n9 run view "$id" --json status | jq .status -r)

notify-send \
  "Deployment to ${environment} has finished!" \
  "${name}\nStarted at ${createdAt}\nStatus: ${status}"
