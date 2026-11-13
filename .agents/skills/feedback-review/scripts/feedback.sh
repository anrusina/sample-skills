#!/usr/bin/env bash
# Fetch the feedback issues filed since the last review, and record a review.
# The timestamp lives in .feedback-last-reviewed at the primary checkout's
# root, so it outlives any worktree; it is kept out of git through
# .git/info/exclude when .gitignore doesn't cover it.
#
# Usage: feedback.sh [--wrap '<prefix>'] <command> ...
#   fetch [--milestone <m>] <label>...
#       prints since=<last review, or none>, started=<now>, then one JSON
#       object per open issue carrying any of the labels, filed since the
#       last review (all open ones on a first run), merged by number
#   stamp <timestamp>
#       record a review; pass the started= value fetch printed, so feedback
#       filed while the review ran is picked up next time
set -euo pipefail

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2; exit 2; }
WRAP=()
if [ "${1:-}" = "--wrap" ]; then
  [ $# -ge 2 ] || usage
  read -r -a WRAP <<<"$2"; shift 2
fi
run() { ${WRAP[@]+"${WRAP[@]}"} "$@"; }
root=$(dirname "$(run git rev-parse --path-format=absolute --git-common-dir)")
file="$root/.feedback-last-reviewed"

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  fetch)
    milestone=()
    if [ "${1:-}" = "--milestone" ]; then
      [ $# -ge 2 ] || usage
      milestone=(--milestone "$2"); shift 2
    fi
    [ $# -ge 1 ] || usage
    since=$(cat "$file" 2>/dev/null || true)
    echo "since=${since:-none}"
    echo "started=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    search=()
    [ -z "$since" ] || search=(--search "created:>=$since")
    # One call per label: several --label flags match issues carrying all of
    # them, not any. The search filters on the server, so --limit never cuts
    # new items off before the date filter.
    for label in "$@"; do
      run gh issue list --label "$label" ${milestone[@]+"${milestone[@]}"} \
        ${search[@]+"${search[@]}"} --state open --limit 1000 \
        --json number,title,body,labels,createdAt \
        --jq '.[] | "\(.number)\t\(tojson)"'
    done | sort -t "$(printf '\t')" -k1,1n -u | cut -f2-
    ;;
  stamp)
    [ $# -eq 1 ] || usage
    printf '%s\n' "$1" > "$file"
    if ! run git -C "$root" check-ignore -q .feedback-last-reviewed; then
      echo ".feedback-last-reviewed" >> "$(run git -C "$root" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
    fi
    echo "recorded $1 in $file"
    ;;
  *) usage ;;
esac
