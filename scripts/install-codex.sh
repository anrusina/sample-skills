#!/usr/bin/env bash
# Install the generic skills for Codex, laptop-wide.
#
# Codex reads user-level skills from ~/.agents/skills and, when two skills
# share a name, shows both without saying which wins. So each skill is copied
# under a prefixed folder AND a prefixed frontmatter name
# (commit -> sample-skills-commit), which can't clash with a project's own
# `commit`.
#
# Usage:
#   scripts/install-codex.sh              install or update
#   scripts/install-codex.sh --uninstall  remove what this script installed
#
# CODEX_SKILLS_DIR overrides the target folder (default ~/.agents/skills).
# Re-run after `git pull` to pick up changes. Only folders carrying this
# script's marker file are ever replaced or removed.
set -euo pipefail

PREFIX="sample-skills-"
MARKER=".installed-by-sample-skills"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/.agents/skills"
DEST="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"

remove_installed() {
  # Remove every prefixed folder this script installed (marker present).
  local dir
  for dir in "$DEST/$PREFIX"*; do
    [ -d "$dir" ] || continue
    if [ -f "$dir/$MARKER" ]; then
      rm -rf "$dir"
    else
      echo "skipped $dir: not installed by this script (no $MARKER)" >&2
    fi
  done
}

if [ "${1:-}" = "--uninstall" ]; then
  [ -d "$DEST" ] && remove_installed
  echo "Removed the ${PREFIX}* skills from $DEST"
  exit 0
fi

[ -d "$SRC" ] || { echo "no skills at $SRC" >&2; exit 1; }
mkdir -p "$DEST"

# Start clean so a skill deleted upstream disappears here too.
remove_installed

count=0
for skill in "$SRC"/*/; do
  name="$(basename "$skill")"
  target="$DEST/$PREFIX$name"
  if [ -e "$target" ]; then
    echo "skipped $name: $target exists and was not installed by this script" >&2
    continue
  fi
  cp -R "$skill" "$target"
  # Rename the skill in its frontmatter: only the first `name:` line, and only
  # inside the leading --- block.
  awk -v new="$PREFIX$name" '
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && $0 == "---"    { infm = 0; print; next }
    infm && !done && /^name:/ { print "name: " new; done = 1; next }
    { print }
  ' "$skill/SKILL.md" > "$target/SKILL.md"
  : > "$target/$MARKER"
  count=$((count + 1))
done

echo "Installed $count skills into $DEST as ${PREFIX}<name>"
