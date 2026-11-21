#!/usr/bin/env bash
# Print a pull request's review threads, one JSON object per line:
#   {id, isResolved, path, line, comments: [{databaseId, body, url, author}]}
# GraphQL, because the REST API does not report whether a thread is resolved.
#
# Usage: review-threads.sh [--wrap '<prefix>'] <pr-number> [--all]
#   default  unresolved threads only
#   --all    resolved threads too
set -euo pipefail

usage() { echo "usage: review-threads.sh [--wrap '<prefix>'] <pr-number> [--all]" >&2; exit 2; }
WRAP=()
if [ "${1:-}" = "--wrap" ]; then
  [ $# -ge 2 ] || usage
  read -r -a WRAP <<<"$2"; shift 2
fi
run() { ${WRAP[@]+"${WRAP[@]}"} "$@"; }

[ $# -ge 1 ] || usage
case "$1" in ''|*[!0-9]*) usage ;; esac
pr=$1; shift
filter='select(.isResolved | not)'
case "${1:-}" in
  '') ;;
  --all) filter='.' ;;
  *) usage ;;
esac

read -r owner name < <(run gh repo view --json owner,name --jq '.owner.login + " " + .name')

run gh api graphql --paginate -F owner="$owner" -F name="$name" -F pr="$pr" -f query='
query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
  repository(owner: $owner, name: $name) { pullRequest(number: $pr) {
    reviewThreads(first: 100, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes { id isResolved path line
        comments(first: 50) { nodes { databaseId body url author { login } } } } } } } }' \
  --jq ".data.repository.pullRequest.reviewThreads.nodes[] | $filter | {id, isResolved, path, line, comments: [.comments.nodes[] | {databaseId, body, url, author: .author.login}]}"
