#!/usr/bin/env bash
# Make sure a CI workflow has run on the current head commit, wait for it,
# and report its conclusion. Uses the newest run on the head commit if one
# exists (a pull request that edits the workflow may have started one),
# otherwise starts one on the current branch. Waits until it finishes, so run
# it in the background where the shell limits long commands.
#
# Usage: ci-run.sh [--wrap '<prefix>'] <workflow-file> [--new]
#   --new   start a fresh run even if one exists (after a cancelled run)
#   Prints run=<id> and conclusion=<conclusion>; on any conclusion other than
#   success, also the failing steps' log tail. Exits 0 only on success.
set -euo pipefail

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2; exit 2; }
WRAP=()
if [ "${1:-}" = "--wrap" ]; then
  [ $# -ge 2 ] || usage
  read -r -a WRAP <<<"$2"; shift 2
fi
run() { ${WRAP[@]+"${WRAP[@]}"} "$@"; }

[ $# -ge 1 ] && [ $# -le 2 ] || usage
wf=$1 new=
[ $# -eq 1 ] || { [ "$2" = "--new" ] || usage; new=1; }

head=$(run git rev-parse HEAD)
latest() { run gh run list --workflow "$wf" --commit "$head" --limit 1 --json databaseId --jq '.[0].databaseId // empty'; }
id=
[ -n "$new" ] || id=$(latest)
if [ -z "$id" ]; then
  before=$(latest)
  run gh workflow run "$wf" --ref "$(run git branch --show-current)" >&2
  for _ in $(seq 1 30); do
    sleep 4
    id=$(latest)
    [ -z "$id" ] || [ "$id" = "$before" ] || break
    id=
  done
  [ -n "$id" ] || { echo "ci-run.sh: the started run did not appear within 2 minutes" >&2; exit 1; }
fi
echo "run=$id"
run gh run watch "$id" --exit-status >/dev/null 2>&1 || true
conclusion=$(run gh run view "$id" --json conclusion -q .conclusion)
echo "conclusion=$conclusion"
if [ "$conclusion" != success ]; then
  run gh run view "$id" --log-failed 2>/dev/null | tail -60 || true
  exit 1
fi
