#!/usr/bin/env bash
# Resolve a pull request for review and decide whether this is a follow-up
# round. Every summary /review-pr posts ends with the marker
# "review-pr: reviewed <sha>"; a follow-up round reviews only the commits
# since the latest marked one.
#
# Usage: review-round.sh [--wrap '<prefix>'] <pr-number> [--full]
#   Prints key=value lines: number, title, state (OPEN, CLOSED or MERGED),
#   draft, base, head, head_sha, last_sha (empty when no earlier round),
#   round (follow-up or full) and reason (why a full review, when it is one).
#   --full forces round=full. Fetches the PR head so head_sha is local.
set -euo pipefail

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2; exit 2; }
WRAP=()
if [ "${1:-}" = "--wrap" ]; then
  [ $# -ge 2 ] || usage
  read -r -a WRAP <<<"$2"; shift 2
fi
run() { ${WRAP[@]+"${WRAP[@]}"} "$@"; }

[ $# -ge 1 ] && [ $# -le 2 ] || usage
case "$1" in ''|*[!0-9]*) usage ;; esac
pr=$1 full=
[ $# -eq 1 ] || { [ "$2" = "--full" ] || usage; full=1; }

run gh pr view "$pr" --json number,title,state,isDraft,baseRefName,headRefName,headRefOid \
  --jq '"number=\(.number)\ntitle=\(.title)\nstate=\(.state)\ndraft=\(.isDraft)\nbase=\(.baseRefName)\nhead=\(.headRefName)\nhead_sha=\(.headRefOid)"'
head_sha=$(run gh pr view "$pr" --json headRefOid -q .headRefOid)
run git fetch -q origin "pull/$pr/head" 2>/dev/null || run git fetch -q origin

last=$(run gh api "repos/{owner}/{repo}/pulls/$pr/reviews?per_page=100" --paginate \
  --jq '.[].body | select(test("review-pr: reviewed [0-9a-f]{40}")) | capture("review-pr: reviewed (?<sha>[0-9a-f]{40})").sha' \
  | tail -1)
echo "last_sha=$last"

round=full reason=
if [ -n "$full" ]; then
  reason="--full was passed"
elif [ -z "$last" ]; then
  reason="no earlier /review-pr round"
elif ! run git merge-base --is-ancestor "$last" "$head_sha" 2>/dev/null; then
  reason="the branch was rebased or force-pushed since $last"
elif [ -n "$(run git rev-list --merges "$last..$head_sha")" ]; then
  reason="the default branch was merged in since $last"
else
  round=follow-up
fi
echo "round=$round"
echo "reason=$reason"
