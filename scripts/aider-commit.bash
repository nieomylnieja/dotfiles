#! /usr/bin/env bash

set -eu

STASH_NAME="aider: only unstaged changes"
COMMIT_PROMPT=$(
  cat <<EOF
use conventional commits with multi-paragraph body,
do not add multiple "feat: ..." parapgraphs, only one (as per conventional commits)
only describe the changes in the body if they are complex,
when desribing changes, only summarize and do not add any suggestions,
otherwise provide only commit title,
do not wrap the commit in markdown code fences,
keep the line length to 120 at most,
split the long lines using semantic line breaks
EOF
)

# Function to unstash changes.
unstash_changes() {
  if git stash list | grep -q "$STASH_NAME"; then
    echo "Unstashing changes..."
    stash_ref=$(git stash list | grep "$STASH_NAME" | head -1 | awk -F: '{print $1}')
    if git stash apply "$stash_ref"; then
      echo "Successfully applied stash, removing it..."
      git stash drop "$stash_ref"
    else
      echo "Failed to apply stash $stash_ref, leaving it in stash list"
    fi
  fi
}

# Set up trap to ensure unstash runs even if script exits with error.
trap unstash_changes EXIT

# If this isn't a git repo, just exit.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repo. Exiting."
  exit 1
fi

# If repo is clean, just exit
if git diff-index --quiet HEAD --; then
  echo "Repo is clean. Nothing to commit. Exiting."
  exit 0
fi

# Check if there are any staged changes to commit
if git diff-index --quiet --cached HEAD --; then
  echo "No staged changes to commit. Exiting."
  exit 0
fi

# If there are unstaged changes, stash them.
# aider does not allow selective commiting of such changes,
# it commits all the changes.
git stash push --quiet --keep-index -m "$STASH_NAME"

# Perform the commit, and push if the user says so.
if aider --commit --commit-prompt="$COMMIT_PROMPT"; then
  echo
  git show -1 --color

  read -p "Do you want to push the commit? (y/n): " -r push_choice
  case "$push_choice" in
  [Yy] | [Yy][Ee][Ss])
    echo "Pushing commit..."
    git push
    ;;
  *)
    echo "Skipping push."
    ;;
  esac
else
  echo "aider --commit failed. Changes will be unstashed."
  exit 1
fi

# Unstash will be handled by the EXIT trap.
