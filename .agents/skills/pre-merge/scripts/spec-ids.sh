#!/usr/bin/env bash
# Cross-check EARS spec IDs and the @spec tags that cite them. Run from the
# repository root. An ID is UPPER-CASE letters, digits and dashes, a dash, a
# number and an optional lower-case letter (GRID-001, CART-12b). EARS files
# define IDs either as a table row (| GRID-001 | …) or as a line
# (GRID-001: When …), each optionally marked [DEPRECATED <date>].
#
# Usage: spec-ids.sh [--wrap '<prefix>'] [--specs <dir>] <command> [<path>...]
#   defined         every defined ID and its status: ID<TAB>active|deprecated
#   dupes           IDs defined more than once (prints nothing when unique);
#                   exits 3 if no ID is found at all, which means the files
#                   use a form this script doesn't read
#   tags [path...]  every @spec tag: file:line<TAB>ID
#   orphans [path...]
#                   tags whose ID is not defined, or is deprecated:
#                   file:line<TAB>ID<TAB>undefined|deprecated
#   added <ref> [path...]
#                   IDs tagged on lines added since <ref> (git diff <ref>...HEAD)
#
# --specs defaults to docs/specs (files EARS-*.md). Paths default to every
# tracked file outside docs/, .agents/ and .claude/ that is not Markdown, so
# a skill's or a doc's own @spec examples never count as tags.
set -euo pipefail

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2; exit 2; }
WRAP=()
specs=docs/specs
while [ $# -gt 0 ]; do
  case "$1" in
    --wrap) [ $# -ge 2 ] || usage; read -r -a WRAP <<<"$2"; shift 2 ;;
    --specs) [ $# -ge 2 ] || usage; specs=$2; shift 2 ;;
    *) break ;;
  esac
done
run() { ${WRAP[@]+"${WRAP[@]}"} "$@"; }

ID='[A-Z][A-Z0-9]*(-[A-Z0-9]+)*-[0-9]+[a-z]?'
DEP='\[DEPRECATED[^]]*\][[:space:]]*'

defined() {
  local files
  files=$(ls "$specs"/EARS-*.md 2>/dev/null || true)
  [ -n "$files" ] || return 0
  # shellcheck disable=SC2086
  grep -hE "^(\|[[:space:]]*|[-*][[:space:]]+)?($DEP)?(\*\*)?$ID(\*\*)?([[:space:]]*\||:)" $files \
    | sed -E "s/^(\|[[:space:]]*|[-*][[:space:]]+)?//" \
    | awk -v id="$ID" '{
        status = ($0 ~ /^\[DEPRECATED/) ? "deprecated" : "active"
        if (match($0, id)) print substr($0, RSTART, RLENGTH) "\t" status
      }'
}

pathspec() {
  if [ $# -gt 0 ]; then printf '%s\n' "$@"
  else printf '%s\n' . ':(exclude)docs' ':(exclude).agents' ':(exclude).claude' ':(exclude)*.md' ':(exclude)*.mdx'
  fi
}

tags() {
  local ps=()
  while IFS= read -r p; do ps+=("$p"); done < <(pathspec "$@")
  local out rc=0
  # git grep exits 1 for "no match"; anything higher is a real failure.
  out=$(run git grep -nIE "@spec[[:space:]]+$ID" -- "${ps[@]}") || rc=$?
  [ $rc -le 1 ] || exit $rc
  [ -n "$out" ] || return 0
  printf '%s\n' "$out" | awk -v id="$ID" '{
        n = index($0, ":"); m = index(substr($0, n + 1), ":")
        loc = substr($0, 1, n + m - 1); rest = substr($0, n + m + 1)
        while (match(rest, "@spec[[:space:]]+" id)) {
          tag = substr(rest, RSTART, RLENGTH); sub(/^@spec[[:space:]]+/, "", tag)
          print loc "\t" tag; rest = substr(rest, RSTART + RLENGTH)
        }
      }'
}

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  defined) [ $# -eq 0 ] || usage; defined ;;
  dupes)
    [ $# -eq 0 ] || usage
    all=$(defined)
    if [ -z "$all" ]; then
      echo "spec-ids.sh: no spec ID found in $specs/EARS-*.md" >&2; exit 3
    fi
    printf '%s\n' "$all" | cut -f1 | sort | uniq -d
    ;;
  tags) tags "$@" ;;
  orphans)
    t=$(tags "$@")
    [ -n "$t" ] || exit 0
    awk -F'\t' '
      FNR == NR { if (st[$1] != "active") st[$1] = $2; next }
      { s = st[$2]; if (s == "") print $1 "\t" $2 "\tundefined"; else if (s == "deprecated") print $1 "\t" $2 "\tdeprecated" }
    ' <(defined) <(printf '%s\n' "$t")
    ;;
  added)
    [ $# -ge 1 ] || usage
    ref=$1; shift
    ps=()
    while IFS= read -r p; do ps+=("$p"); done < <(pathspec "$@")
    run git rev-parse -q --verify "$ref^{commit}" >/dev/null \
      || { echo "spec-ids.sh: unknown ref $ref" >&2; exit 1; }
    diff=$(run git diff -U0 "$ref...HEAD" -- "${ps[@]}")
    printf '%s\n' "$diff" \
      | grep -E "^\+[^+].*@spec[[:space:]]+$ID|^\+@spec" \
      | grep -oE "@spec[[:space:]]+$ID" | sed -E 's/^@spec[[:space:]]+//' | sort -u || true
    ;;
  *) usage ;;
esac
