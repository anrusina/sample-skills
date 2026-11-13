#!/usr/bin/env bash
# The mechanical half of /setup-skills: render upstream skills with a
# project's facts, write the lock, and plan and apply an update. The skill
# itself works out the facts, writes the profile, asks the questions and
# decides conflicts; this script only does what has one right answer.
#
# Run from the project's top level. <profile> is .agents/skills-profile.md, or
# for a detached copy a temporary profile in the same format. <clone> is an
# upstream checkout; <skills> is its .agents/skills folder at the wanted commit.
#
# Usage: setup.sh [--wrap '<prefix>'] <command> ...
#   render <profile> <skills> <skill>
#       write .agents/skills/<skill>/ from <skills>/<skill>/, deleting the old
#       folder first: the connected assets only, the facts block rendered,
#       the description's generic sentence removed, allowed-tools adapted
#   render-file <profile> <skill> <upstream-file> <rel-path>
#       print one upstream file as render would write it (rel-path is its
#       path inside the skill, e.g. SKILL.md or assets/index.md)
#   rerender <profile> <skills> [<skill>...]
#       rewrite only the facts block, description and allowed-tools of each
#       installed SKILL.md (all installed skills when none is named), keeping
#       every other line, so profile edits and add/remove reach them
#   lock <profile> <commit>
#       write .agents/skills-lock.json: source, ref and commit from the
#       profile and <commit>, and the git hash of every installed file
#   plan <profile> <clone> <old> <new>
#       print one "<action> <path>" line per file an update touches, where
#       action is new, write, rerender, keep, merge, delete, ask-delete,
#       ask-new (a new upstream file whose path the project already uses)
#       or gone (installed once, deleted by the project since)
#   update <profile> <clone> <old> <new>
#       apply the plan: new, write, rerender, delete and clean merges are
#       written; merge conflicts, ask-delete and ask-new are left untouched
#       and listed with the files to compare. Writes the lock only when
#       nothing is left to decide; otherwise run lock after deciding.
#   assets <profile> <skills>
#       after the profile's assets changed: copy in connected asset files
#       that are missing, remove unconnected ones (an edited one is listed,
#       not removed), rewrite each assets/index.md and rerender
#
# Profile: YAML frontmatter, a small subset. Top-level keys kind (managed or
# detached), source, ref, skills, kept, assets, wrapped-tools; facts nested
# under facts: by row name (lower case, spaces as dashes, <repo> as repo).
# A value is one line, an inline list [a, b], a block list of "- item"
# lines, or a "|" block of indented lines.
set -euo pipefail

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2; exit 2; }
WRAP=()
if [ "${1:-}" = "--wrap" ]; then
  [ $# -ge 2 ] || usage
  read -r -a WRAP <<<"$2"; shift 2
fi
run() { ${WRAP[@]+"${WRAP[@]}"} "$@"; }
die() { echo "setup.sh: $*" >&2; exit 1; }

DEST=.agents/skills
LOCK=.agents/skills-lock.json

# --- profile -----------------------------------------------------------------

# pget <profile> <key> [facts]: the value, one item per line ("" if absent).
pget() {
  awk -v want="$2" -v nested="${3:-}" '
    function emit(v) { sub(/[ \t]+$/, "", v); if (v != "") print v }
    function trim(v) { sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v); return v }
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---" { exit }
    !inside { next }
    {
      line = $0
      match(line, /^ */); ind = RLENGTH
      if (mode == "block") {
        if (ind > keyind || trim(line) == "") { emit(substr(line, keyind + 3)); next }
        exit
      }
      if (mode == "list") {
        if (ind > keyind && trim(line) ~ /^- /) { v = trim(line); emit(substr(v, 3)); next }
        exit
      }
      if (ind == 0) section = (line ~ /^facts:[ \t]*$/) ? "facts" : ""
      wantind = nested ? 2 : 0
      if (nested && section != "facts") next
      if (ind != wantind) next
      k = trim(line); i = index(k, ":"); if (i == 0) next
      key = substr(k, 1, i - 1); val = trim(substr(k, i + 1))
      if (key != want) next
      keyind = ind
      if (val == "|" || val == "|-") { mode = "block"; next }
      if (val == "") { mode = "list"; next }
      if (val ~ /^\[.*\]$/) {
        val = substr(val, 2, length(val) - 2)
        n = split(val, a, ","); for (j = 1; j <= n; j++) emit(trim(a[j]))
        exit
      }
      gsub(/^"|"$/, "", val); emit(val); exit
    }' "$1"
}

has_line() { case $'\n'"$1"$'\n' in *$'\n'"$2"$'\n'*) return 0 ;; esac; return 1; }

# --- rendering -----------------------------------------------------------------

# facts_block <profile> <skill> <generic SKILL.md>: the project form of the
# block, from the generic block's rows.
facts_block() {
  local profile=$1 skill=$2 generic=$3
  local kind installed assets wrapper
  kind=$(pget "$profile" kind); kind=${kind:-managed}
  installed=$(pget "$profile" skills)
  assets=$(present_assets "$profile" "$(dirname "$generic")")
  wrapper=$(pget "$profile" wrapper facts)

  if [ "$kind" = detached ]; then
    echo "Written by /setup-skills when this copy was made. This is the project's"
    echo "own copy: edit these values here."
  else
    echo "Written by /setup-skills from \`.agents/skills-profile.md\` (managed copy:"
    echo "edit the profile and run \`/setup-skills update\`, not this block)."
  fi
  echo

  # rows: "<fact name><TAB><rule>" between the markers
  awk '/<!-- facts:begin -->/ { on = 1; next } /<!-- facts:end -->/ { on = 0 }
       on && /^\| / && !/^\| Fact \|/ && !/^\|---/ {
         gsub(/\\\|/, "\001")
         n = split($0, c, "|"); name = c[2]; rule = c[3]
         for (i = 4; i < n; i++) rule = rule "|" c[i]
         gsub(/^ +| +$/, "", name); gsub(/^ +| +$/, "", rule); gsub("\001", "\\|", rule)
         print name "\t" rule }' "$generic" |
  while IFS="$(printf '\t')" read -r name rule; do
    key=$(printf '%s' "$name" | tr -d '`<>' | tr 'A-Z ' 'a-z-')
    case "$key" in
      skill-names)
        list=$(printf '%s\n' "$installed" | sed 's|^|`/|; s|$|`|' | paste -sd, - | sed 's/,/, /g')
        echo "- **$name**: ${list:-none} run from this project's copy; any other skill as \`/sample-skills:<name>\` from the plugin. Other skills are named in this file in their short form (\`/<name>\`); write each in the form this gives"
        continue ;;
      assets)
        if [ -n "$assets" ]; then
          echo "- **$name**: every file under \`assets/stack/\` and \`assets/field/\` applies ($(printf '%s\n' "$assets" | paste -sd, - | sed 's/,/, /g'))"
        else
          echo "- **$name**: none connected"
        fi
        continue ;;
    esac
    if [ "${rule#*read at run time}" != "$rule" ]; then
      echo "- **$name**: $rule"; continue
    fi
    value=$(pget "$profile" "$key" facts)
    apply=$(printf '%s' "$rule" | sed -n 's/.*, or none\. \(.*\)$/\1/p')
    if [ -z "$value" ] || [ "$value" = none ]; then
      tail=$(printf '%s' "$rule" | sed -n 's/.*or none (\([^)]*\)).*/ (\1)/p')
      [ -n "$tail" ] || tail=$(printf '%s' "$rule" | sed -n 's/.*without that section, \(.*\)$/; \1/p')
      [ "$key" = wrapper ] && apply=
      echo "- **$name**: none$tail${apply:+. $apply}"
      continue
    fi
    case "$key" in repo|base|wrapper|gates|format-fix|setup) code=1 ;; *) code= ;; esac
    [ "${value#none }" = "$value" ] || code=
    if [ "$(printf '%s\n' "$value" | wc -l)" -gt 1 ]; then
      if [ -n "$code" ]; then
        echo "- **$name**:${apply:+ $apply}"
        printf '%s\n' "$value" | awk '{ printf "  %d. `%s`\n", NR, $0 }'
      else
        echo "- **$name**:${apply:+ $apply}"
        printf '%s\n' "$value" | sed 's/^/  > /; s/ $//'
      fi
    else
      [ -n "$code" ] && value="\`$value\`"
      echo "- **$name**: $value${apply:+. $apply}"
    fi
  done
}

# present_assets <profile> <upstream skill dir>: connected ids this skill has.
present_assets() {
  local id
  for id in $(pget "$1" assets); do
    if [ -f "$2/assets/stack/$id.md" ] || [ -f "$2/assets/field/$id.md" ]; then echo "$id"; fi
  done
}

# render_skill_md <profile> <skill> <generic SKILL.md> <current SKILL.md>:
# the current file with its block, description and allowed-tools re-rendered.
render_skill_md() {
  local profile=$1 skill=$2 generic=$3 current=$4 block wrapper tools adds
  block=$(facts_block "$profile" "$skill" "$generic")
  wrapper=$(pget "$profile" wrapper facts); [ "$wrapper" = none ] && wrapper=
  tools=$(pget "$profile" wrapped-tools)
  adds=$(
    rows=$(awk '/<!-- facts:begin -->/{on=1} /<!-- facts:end -->/{on=0} on' "$generic")
    for key in gates format-fix setup; do
      label=$(printf '%s' "$key" | tr '-' ' ')
      [ "${rows#*"| $label |"}" != "$rows" ] || continue
      pget "$profile" "$key" facts | while IFS= read -r cmd; do
        [ -n "$cmd" ] && [ "$cmd" != none ] || continue
        [ "${cmd#none }" = "$cmd" ] || continue
        echo "  - Bash(${wrapper:+$wrapper }$cmd)"
      done
    done
    if [ -n "$wrapper" ]; then
      for t in $tools; do
        sed -n '/^allowed-tools:/,/^[^ ]/p' "$current" | sed -n "s/^  - Bash($t \(.*\))\$/  - Bash($wrapper $t \1)/p"
      done
    fi
  )
  BLOCK=$block ADDS=$adds awk '
    BEGIN { block = ENVIRON["BLOCK"]; n = split(ENVIRON["ADDS"], add, "\n") }
    NR == 1 && $0 == "---" { fm = 1; print; next }
    fm && /^description:/ { sub(/ Generic copy: if a project skill named [^"]* instead\./, "") }
    fm && /^allowed-tools:/ { inat = 1; print; next }
    fm && inat && /^  - / { seen[$0] = 1; print; next }
    fm && inat { flush(); inat = 0; done = 1 }
    fm && $0 == "---" { if (!done && n > 0 && add[1] != "") { print "allowed-tools:"; flush() } fm = 0; print; next }
    /<!-- facts:begin -->/ { print; print block; skip = 1; next }
    /<!-- facts:end -->/ { skip = 0 }
    !skip { print }
    function flush(  i) { for (i = 1; i <= n; i++) if (add[i] != "" && !seen[add[i]]) { print add[i]; seen[add[i]] = 1 } }
  ' "$current"
}

# render_index <profile> <upstream skill dir> <index.md>: rows of unconnected
# ids removed.
render_index() {
  local keep
  keep=$(present_assets "$1" "$2" | paste -sd'|' -)
  awk -v keep="^(${keep:-.^})\$" '
    /^\| (stack|field) \| `/ { id = $0; sub(/^\| (stack|field) \| `/, "", id); sub(/`.*/, "", id); if (id !~ keep) next }
    { print }' "$3"
}

# wanted <profile> <upstream skill dir>: the files render would write, as
# paths inside the skill.
wanted() {
  local profile=$1 dir=$2 present f id
  present=$(present_assets "$profile" "$dir")
  (cd "$dir" && find . -type f | sed 's|^\./||' | sort) | while IFS= read -r f; do
    case "$f" in
      assets/stack/*|assets/field/*)
        id=$(basename "$f" .md)
        has_line "$present" "$id" && echo "$f" ;;
      assets/index.md) [ -n "$present" ] && echo "$f" ;;
      *) echo "$f" ;;
    esac
  done
}

# render_file <profile> <skill> <upstream file> <rel> [<upstream skill dir>]
render_file() {
  local profile=$1 skill=$2 file=$3 rel=$4 dir=${5:-$(dirname "$3")}
  case "$rel" in
    SKILL.md) render_skill_md "$profile" "$skill" "$file" "$file" ;;
    assets/index.md) render_index "$profile" "$dir" "$file" ;;
    *) cat "$file" ;;
  esac
}

render_skill() {
  local profile=$1 skills=$2 skill=$3 src="$2/$3" rel
  [ -f "$src/SKILL.md" ] || die "no upstream skill $skill in $skills"
  [ "$skill" != setup-skills ] || die "setup-skills is never copied into a project"
  rm -rf "${DEST:?}/$skill"
  wanted "$profile" "$src" | while IFS= read -r rel; do
    mkdir -p "$DEST/$skill/$(dirname "$rel")"
    render_file "$profile" "$skill" "$src/$rel" "$rel" "$src" > "$DEST/$skill/$rel"
    [ ! -x "$src/$rel" ] || chmod +x "$DEST/$skill/$rel"
  done
  echo "rendered $DEST/$skill"
}

# rerender_one: re-render an installed SKILL.md in place. The installed block
# holds values, not rules, so the rows come from the generic upstream file.
rerender_one() {
  local profile=$1 skill=$2 generic=$3 out
  out=$(mktemp)
  render_skill_md "$profile" "$skill" "$generic" "$DEST/$skill/SKILL.md" > "$out"
  mv "$out" "$DEST/$skill/SKILL.md"
}

# --- lock ----------------------------------------------------------------------

lock_files() { [ -f "$LOCK" ] && sed -n 's/^    "\(.*\)": "\([0-9a-f]*\)",\{0,1\}$/\1 \2/p' "$LOCK" || true; }
lock_hash() { lock_files | awk -v p="$1" '$1 == p { print $2 }'; }

write_lock() {
  local profile=$1 commit=$2 source ref files first=1 f
  source=$(pget "$profile" source); ref=$(pget "$profile" ref)
  files=$(for s in $(pget "$profile" skills); do [ -d "$DEST/$s" ] && find "$DEST/$s" -type f; done | sort)
  {
    echo "{"
    echo "  \"source\": \"${source:-anrusina/sample-skills}\","
    echo "  \"ref\": \"${ref}\","
    echo "  \"commit\": \"$commit\","
    echo "  \"files\": {"
    printf '%s\n' "$files" | while IFS= read -r f; do
      [ -n "$f" ] || continue
      [ $first -eq 1 ] || printf ',\n'
      printf '    "%s": "%s"' "$f" "$(run git hash-object "$f")"
      first=0
    done
    printf '\n  }\n}\n'
  } > "$LOCK"
  echo "wrote $LOCK at $commit"
}

# --- update --------------------------------------------------------------------

plan() {
  local profile=$1 clone=$2 old=$3 new=$4 kept skills tmp s rel p h ours_h
  kept=$(pget "$profile" kept); skills=$(pget "$profile" skills)
  tmp=$(mktemp -d)
  run git -C "$clone" worktree add -q --detach "$tmp/new" "$new" >/dev/null
  {
    lock_files | awk '{ print $1 }'
    for s in $skills; do
      has_line "$kept" "$s" && continue
      [ -d "$tmp/new/.agents/skills/$s" ] || continue
      wanted "$profile" "$tmp/new/.agents/skills/$s" | sed "s|^|$DEST/$s/|"
    done
  } | sort -u | while IFS= read -r p; do
    s=$(printf '%s' "$p" | cut -d/ -f3)
    has_line "$kept" "$s" && continue
    rel=${p#"$DEST/$s/"}
    h=$(lock_hash "$p")
    in_new=; [ -f "$tmp/new/$p" ] && has_line "$(wanted "$profile" "$tmp/new/.agents/skills/$s")" "$rel" && in_new=1
    if [ -z "$h" ]; then
      if [ -e "$p" ]; then echo "ask-new $p"; else echo "new $p"; fi
      continue
    fi
    [ -e "$p" ] || { echo "gone $p"; continue; }
    ours_h=$(run git hash-object "$p")
    if [ -z "$in_new" ]; then
      if [ "$ours_h" = "$h" ]; then echo "delete $p"; else echo "ask-delete $p"; fi
      continue
    fi
    if [ "$ours_h" = "$h" ]; then echo "write $p"; continue; fi
    if run git -C "$clone" diff --quiet "$old" "$new" -- "$p"; then
      if [ "$rel" = SKILL.md ]; then echo "rerender $p"; else echo "keep $p"; fi
    else
      echo "merge $p"
    fi
  done
  run git -C "$clone" worktree remove --force "$tmp/new"
  rm -rf "$tmp"
}

update() {
  local profile=$1 clone=$2 old=$3 new=$4 tmp action p s rel left=0 conflicts
  tmp=$(mktemp -d); conflicts=$(mktemp -d "${TMPDIR:-/tmp}/setup-skills-conflicts-XXXXXX")
  run git -C "$clone" worktree add -q --detach "$tmp/old" "$old" >/dev/null
  run git -C "$clone" worktree add -q --detach "$tmp/new" "$new" >/dev/null
  plan "$profile" "$clone" "$old" "$new" > "$tmp/plan"
  while read -r action p; do
    s=$(printf '%s' "$p" | cut -d/ -f3); rel=${p#"$DEST/$s/"}
    case "$action" in
      new|write)
        mkdir -p "$(dirname "$p")"
        render_file "$profile" "$s" "$tmp/new/$p" "$rel" "$tmp/new/.agents/skills/$s" > "$p"
        [ ! -x "$tmp/new/$p" ] || chmod +x "$p"
        echo "$action $p" ;;
      rerender)
        rerender_one "$profile" "$s" "$tmp/new/$p"; echo "rerender $p" ;;
      keep|gone) echo "$action $p" ;;
      delete) rm -f "$p"; echo "delete $p" ;;
      merge)
        base="$conflicts/$s-$(basename "$rel").base"; theirs="$conflicts/$s-$(basename "$rel").theirs"
        if [ -f "$tmp/old/$p" ]; then
          render_file "$profile" "$s" "$tmp/old/$p" "$rel" "$tmp/old/.agents/skills/$s" > "$base"
        else : > "$base"; fi
        render_file "$profile" "$s" "$tmp/new/$p" "$rel" "$tmp/new/.agents/skills/$s" > "$theirs"
        out=$(mktemp)
        if run git merge-file -p "$p" "$base" "$theirs" > "$out"; then
          mv "$out" "$p"
          [ "$rel" != SKILL.md ] || rerender_one "$profile" "$s" "$tmp/new/$p"
          rm -f "$base" "$theirs"
          echo "merged $p"
        else
          mv "$out" "$conflicts/$s-$(basename "$rel").merged"
          echo "conflict $p base=$base theirs=$theirs merged=$conflicts/$s-$(basename "$rel").merged"
          left=1
        fi ;;
      ask-delete|ask-new)
        echo "$action $p upstream=$tmp/new/$p"; left=1 ;;
    esac
  done < "$tmp/plan"
  if [ $left -eq 0 ]; then
    write_lock "$profile" "$new"
    run git -C "$clone" worktree remove --force "$tmp/old"
    run git -C "$clone" worktree remove --force "$tmp/new"
    rm -rf "$tmp" "$conflicts"
  else
    echo "decisions left: write each chosen file, then run: setup.sh lock $profile $new"
    echo "upstream trees kept for comparing: old=$tmp/old new=$tmp/new"
  fi
}

assets() {
  local profile=$1 skills=$2 s f id present
  for s in $(pget "$profile" skills); do
    [ -d "$DEST/$s" ] || continue
    has_line "$(pget "$profile" kept)" "$s" && continue
    present=$(present_assets "$profile" "$skills/$s")
    for f in "$skills/$s"/assets/stack/*.md "$skills/$s"/assets/field/*.md; do
      [ -f "$f" ] || continue
      id=$(basename "$f" .md); rel=${f#"$skills/$s/"}
      if has_line "$present" "$id"; then
        [ -e "$DEST/$s/$rel" ] || { mkdir -p "$(dirname "$DEST/$s/$rel")"; cp "$f" "$DEST/$s/$rel"; echo "connect $DEST/$s/$rel"; }
      elif [ -e "$DEST/$s/$rel" ]; then
        h=$(lock_hash "$DEST/$s/$rel")
        if [ -n "$h" ] && [ "$(run git hash-object "$DEST/$s/$rel")" != "$h" ]; then
          echo "edited, not removed: $DEST/$s/$rel"
        else
          rm -f "$DEST/$s/$rel"; echo "disconnect $DEST/$s/$rel"
        fi
      fi
    done
    if [ -n "$present" ] && [ -f "$skills/$s/assets/index.md" ]; then
      render_index "$profile" "$skills/$s" "$skills/$s/assets/index.md" > "$DEST/$s/assets/index.md"
    else
      rm -f "$DEST/$s/assets/index.md"
    fi
    rmdir "$DEST/$s/assets/stack" "$DEST/$s/assets/field" "$DEST/$s/assets" 2>/dev/null || true
    rerender_one "$profile" "$s" "$skills/$s/SKILL.md"
  done
}

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  render) [ $# -eq 3 ] || usage; render_skill "$@" ;;
  render-file) [ $# -eq 4 ] || usage; render_file "$1" "$2" "$3" "$4" ;;
  rerender)
    [ $# -ge 2 ] || usage
    profile=$1 skills=$2; shift 2
    [ $# -gt 0 ] || set -- $(pget "$profile" skills)
    for s in "$@"; do
      [ -d "$DEST/$s" ] || continue
      rerender_one "$profile" "$s" "$skills/$s/SKILL.md"; echo "rerender $DEST/$s/SKILL.md"
    done ;;
  lock) [ $# -eq 2 ] || usage; write_lock "$@" ;;
  plan) [ $# -eq 4 ] || usage; plan "$@" ;;
  update) [ $# -eq 4 ] || usage; update "$@" ;;
  assets) [ $# -eq 2 ] || usage; assets "$@" ;;
  *) usage ;;
esac
