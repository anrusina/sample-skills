#!/usr/bin/env bash
# Check that every copy of a shared skill script is identical. Each skill
# carries its own copy of the scripts it uses (a skill must stand alone), so
# a fix made in one copy has to reach the others.
#
# Usage: scripts/check-shared-scripts.sh   (exits 1 and names the copies that differ)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
status=0
for name in $(find .agents/skills -path '*/scripts/*' -type f -exec basename {} \; | sort -u); do
  copies=$(find .agents/skills -path "*/scripts/$name" -type f | sort)
  first=$(printf '%s\n' "$copies" | head -1)
  printf '%s\n' "$copies" | while IFS= read -r copy; do
    cmp -s "$first" "$copy" || { echo "differs: $copy (from $first)"; exit 1; }
  done || status=1
done
[ $status -eq 0 ] && echo "shared scripts: every copy identical"
exit $status
