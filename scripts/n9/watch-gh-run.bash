#!/usr/bin/env bash

set -e

environment=$(gh api /repos/nobl9/n9/environments --jq .environments[].name | fzf)

if [[ $(git -C ~/nobl9/n9 ls-remote --heads origin "refs/heads/${environment}" | wc -l) == 0 ]]; then
  echo "Branch ${environment} does not exist"
fi

# Get list of workflow runs and let user select with fzf
runs=$(gh -R nobl9/n9 run list --branch="$environment" \
  --json name,createdAt,status,databaseId,conclusion \
  --jq '.[] | select(.name | startswith("Build and deploy"))')

# Save runs to temp file for preview access
tmpfile=$(mktemp)
echo "$runs" > "$tmpfile"
trap "rm -f $tmpfile" EXIT

selectedRun=$(echo "$runs" | jq -r '. | "\(.databaseId)\t\(.name)"' | \
  fzf --delimiter='\t' --with-nth=2 --header="Workflow Name" \
    --preview "jq -r 'select(.databaseId == {1}) |
      \"Status: \" + .status + \"\n\" +
      \"Conclusion: \" + (.conclusion // \"N/A\") + \"\n\" +
      \"Started: \" + .createdAt + \"\n\" +
      \"Run ID: \" + (.databaseId | tostring)' '$tmpfile'" \
    --preview-window=right:40%:wrap | cut -f1)

if [[ -z "$selectedRun" ]]; then
  echo "No workflow selected"
  exit 1
fi

id="$selectedRun"
runInfo=$(echo "$runs" | jq -r "select(.databaseId == $id)")
name=$(jq -r .name <<<"$runInfo")
createdAt=$(jq -r .createdAt <<<"$runInfo")
status=$(jq -r .status <<<"$runInfo")
conclusion=$(jq -r .conclusion <<<"$runInfo")

# If workflow is still running, watch it
if [[ $status != "completed" ]]; then
  echo "Watching workflow run..."
  gh -R nobl9/n9 run watch --interval=10 "$id"
fi

# Get final results
runResult=$(gh -R nobl9/n9 run view "$id" --json conclusion,jobs)
conclusion=$(jq -r .conclusion <<<"$runResult")

if [[ $conclusion == "failure" ]]; then
  # Prepare notification message with failed jobs summary
  failedJobsCount=$(jq -r '[.jobs[] | select(.conclusion == "failure")] | length' <<<"$runResult")
  failedJobsList=$(jq -r '.jobs[] | select(.conclusion == "failure") | "• " + .name' <<<"$runResult" | head -5)

  notificationBody="${name}\nStarted at ${createdAt}\n\n${failedJobsCount} job(s) failed:\n${failedJobsList}"

  notify-send \
    "❌ Deployment to ${environment} FAILED!" \
    "$notificationBody"

  # Collect detailed failure information for Claude
  failureDetails=$(jq -r '.jobs[] | select(.conclusion == "failure") |
    "## Failed Job: \(.name)\n" +
    "URL: \(.html_url // "N/A")\n" +
    "Started: \(.startedAt // "N/A")\n" +
    "Completed: \(.completedAt // "N/A")\n\n" +
    "### Failed Steps:\n" +
    (
      [.steps[] | select(.conclusion == "failure") |
        "- **\(.name)**\n" +
        "  - Number: \(.number)\n" +
        "  - Started: \(.startedAt // "N/A")\n" +
        "  - Completed: \(.completedAt // "N/A")\n"
      ] | join("\n")
    ) + "\n---\n"' <<<"$runResult")

  # Create the prompt for Claude
  claudePrompt="The GitHub Actions deployment to ${environment} has failed.

## Deployment Information
- Workflow: ${name}
- Branch/Environment: ${environment}
- Started at: ${createdAt}
- Run ID: ${id}
- Run URL: https://github.com/nobl9/n9/actions/runs/${id}

## Failure Details
${failureDetails}

Please investigate why this deployment failed. Check the relevant workflow files, recent commits on the ${environment} branch, and any related configuration that might have caused these failures."

  # Change to the repository directory and launch Claude Code
  cd ~/nobl9/n9 || exit 1
  claude "$claudePrompt"

  exit 0
else
  notify-send \
    "✅ Deployment to ${environment} completed successfully!" \
    "${name}\nStarted at ${createdAt}"
fi
