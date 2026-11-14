#!/usr/bin/env bash
# Install the generic skills for Codex, laptop-wide.
#
# Codex reads user-level skills from ~/.agents/skills and, when two skills
# share a name, shows both without saying which wins. So each skill is copied
# under a prefixed folder AND a prefixed frontmatter name
# (commit -> sample-skills-commit), which can't clash with a project's own
# `commit`. ${CLAUDE_SKILL_DIR}, which Claude Code fills in itself, is
# replaced by the installed folder's path.
#
# Not installed: setup-skills (it is the Claude Code plugin's installer) and
# the coordinator roles coding-master and managerial (they need the Claude
# desktop app's session tools).
#
# Usage:
#   scripts/install-codex.sh              install or update
#   scripts/install-codex.sh --uninstall  remove what this script installed
#   scripts/install-codex.sh --help       print this text
#
# CODEX_SKILLS_DIR overrides the target folder (default ~/.agents/skills).
# Re-run after `git pull` to pick up changes. Only folders carrying this
# script's marker file are ever replaced or removed, and each skill is built
# in a temporary folder and moved into place only once complete, so an
# interrupted run never leaves a half-copied skill.
set -euo pipefail

PREFIX="sample-skills-"
MARKER=".installed-by-sample-skills"
SKIP=" setup-skills coding-master managerial "
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/.agents/skills"
DEST="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; }

remove_installed() {
  # Remove prefixed folders this script installed (marker present) whose
  # skill is not in the list given (all of them when the list is empty).
  local keep=" $* " dir name
  for dir in "$DEST/$PREFIX"*; do
    [ -d "$dir" ] || continue
    name=${dir##*/}; name=${name#"$PREFIX"}
    [ "${keep#* "$name" }" = "$keep" ] || continue
    if [ -f "$dir/$MARKER" ]; then
      rm -rf "$dir"
    else
      echo "skipped $dir: not installed by this script (no $MARKER)" >&2
    fi
  done
}

case "${1:-}" in
  "") ;;
  --uninstall)
    [ $# -eq 1 ] || { usage >&2; exit 2; }
    [ -d "$DEST" ] && remove_installed
    echo "Removed the ${PREFIX}* skills from $DEST"
    exit 0 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[ $# -le 1 ] || { usage >&2; exit 2; }

[ -d "$SRC" ] || { echo "no skills at $SRC" >&2; exit 1; }
mkdir -p "$DEST"

BUILD=$(mktemp -d "$DEST/.${PREFIX}build-XXXXXX")
trap 'rm -rf "$BUILD"' EXIT

count=0 installed=""
for skill in "$SRC"/*/; do
  name="$(basename "$skill")"
  [ "${SKIP#* "$name" }" = "$SKIP" ] || continue
  target="$DEST/$PREFIX$name"
  if [ -e "$target" ] && [ ! -f "$target/$MARKER" ]; then
    echo "skipped $name: $target exists and was not installed by this script" >&2
    continue
  fi
  work="$BUILD/$name"
  cp -R "$skill" "$work"
  # Rename the skill in its frontmatter: only the first `name:` line, and only
  # inside the leading --- block.
  awk -v new="$PREFIX$name" '
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && $0 == "---"    { infm = 0; print; next }
    infm && !done && /^name:/ { print "name: " new; done = 1; next }
    { print }
  ' "$skill/SKILL.md" > "$work/SKILL.md"
  find "$work" -name '*.md' -type f | while IFS= read -r f; do
    sed "s|\${CLAUDE_SKILL_DIR}|$target|g" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  done
  : > "$work/$MARKER"
  rm -rf "$target"
  mv "$work" "$target"
  installed="$installed $name"
  count=$((count + 1))
done

# A skill deleted upstream (or newly skipped) disappears here too.
remove_installed $installed

echo "Installed $count skills into $DEST as ${PREFIX}<name>"
