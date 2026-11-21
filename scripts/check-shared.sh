#!/usr/bin/env bash
# Check the skills' shared folder, .agents/skills/_shared/: every
# ../_shared/<path> a skill names exists, every shared file is named by some
# skill, and no skill keeps its own copy of a shared script.
#
# Usage: scripts/check-shared.sh   (exits 1 and names each problem)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
skills=.agents/skills
status=0

refs=$({ grep -rhoE '\.\./_shared/[A-Za-z0-9_./-]+' "$skills" --exclude-dir=_shared || true; } | sed 's|^\.\./_shared/||; s|[.,)]*$||' | sort -u)
for r in $refs; do
  [ -e "$skills/_shared/$r" ] || { echo "missing: _shared/$r is named but does not exist"; status=1; }
done
while IFS= read -r f; do
  printf '%s\n' "$refs" | grep -qxF "$f" || grep -rqF "_shared/$f" "$skills/_shared" ||
    { echo "unused: _shared/$f is named by no skill"; status=1; }
done < <(cd "$skills/_shared" && find . -type f | sed 's|^\./||')
for f in "$skills"/_shared/scripts/*; do
  [ -e "$f" ] || continue
  for copy in "$skills"/*/scripts/"$(basename "$f")"; do
    case "$copy" in "$skills"/_shared/*) continue ;; esac
    [ ! -e "$copy" ] || { echo "copy: $copy duplicates _shared/scripts/$(basename "$f")"; status=1; }
  done
done
[ $status -eq 0 ] && echo "shared files: all named, all present, no copies"
exit $status
