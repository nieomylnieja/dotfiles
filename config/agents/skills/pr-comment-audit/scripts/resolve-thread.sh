#!/usr/bin/env bash
# Resolve or unresolve a PR review thread by its GraphQL node ID.

set -euo pipefail

usage() {
  cat <<'EOF'
resolve-thread.sh — Resolve or unresolve a review thread.

Usage: resolve-thread.sh <--resolve|--unresolve> --id THREAD_ID

Options:
  --resolve     Resolve the thread
  --unresolve   Unresolve the thread
  --id ID       GraphQL node ID of the thread
  --help        Show this help

Outputs the thread's new isResolved status as JSON.
EOF
  exit 0
}

ACTION=""
THREAD_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resolve)
      ACTION="resolve"
      shift
      ;;
    --unresolve)
      ACTION="unresolve"
      shift
      ;;
    --id)
      THREAD_ID="$2"
      shift 2
      ;;
    --help) usage ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${ACTION}" ]] || [[ -z "${THREAD_ID}" ]]; then
  echo "Error: both action (--resolve/--unresolve) and --id are required" >&2
  exit 1
fi

if [[ "${ACTION}" = "resolve" ]]; then
  MUTATION="resolveReviewThread"
else
  MUTATION="unresolveReviewThread"
fi

gh api graphql -f query="
mutation(\$threadId: ID!) {
  ${MUTATION}(input: { threadId: \$threadId }) {
    thread {
      id
      isResolved
    }
  }
}" -f threadId="${THREAD_ID}" \
  --jq ".data.${MUTATION}.thread | {id, isResolved}"
