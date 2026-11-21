#!/usr/bin/env bash
# Rebuild a rebased branch as documentation first, implementation second,
# keeping every file's content exactly as it was. Run on the branch, after it
# was rebased directly onto origin/<base>, with a clean working tree.
#
# Usage: rebuild.sh [--wrap '<prefix>'] <base> [--docs-msg <file>]
#                   [--impl-msg <file>] [--to-docs <path>]... [--to-impl <path>]...
#   The documentation bucket takes the branch's changes under docs/ plus each
#   --to-docs path, minus each --to-impl path; the implementation bucket takes
#   every other change. A bucket with changes needs its message file (make it
#   with mktemp; it is passed to git commit -F, so backticks stay literal).
#   Only files the branch changed are committed, so untracked files such as
#   linked fixtures never are.
#   Prints pre-rebuild=<sha>, "content identical" and the new commits. If it
#   stops for any reason after pre-rebuild= (a failed commit, content that
#   differs), it prints how to restore and exits non-zero.
set -euo pipefail

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2; exit 2; }
WRAP=()
if [ "${1:-}" = "--wrap" ]; then
  [ $# -ge 2 ] || usage
  read -r -a WRAP <<<"$2"; shift 2
fi
run() { ${WRAP[@]+"${WRAP[@]}"} "$@"; }

[ $# -ge 1 ] || usage
base=$1; shift
docs_msg= impl_msg=
to_docs=() to_impl=()
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || usage
  case "$1" in
    --docs-msg) docs_msg=$2 ;;
    --impl-msg) impl_msg=$2 ;;
    --to-docs) to_docs+=("$2") ;;
    --to-impl) to_impl+=("$2") ;;
    *) usage ;;
  esac
  shift 2
done

if [ -n "$(run git status --porcelain --untracked-files=no)" ]; then
  echo "rebuild.sh: uncommitted changes; commit or ask first" >&2; exit 1
fi
run git merge-base --is-ancestor "origin/$base" HEAD \
  || { echo "rebuild.sh: HEAD is not on top of origin/$base; rebase first" >&2; exit 1; }

pre=$(run git rev-parse HEAD)
changed=$(run git -c core.quotePath=false diff --no-renames --name-only "origin/$base" "$pre")
[ -n "$changed" ] || { echo "rebuild.sh: no changes against origin/$base" >&2; exit 1; }

in_list() { local x=$1; shift; for p in "$@"; do case "$x" in "$p"|"$p"/*) return 0 ;; esac; done; return 1; }
docs=() impl=()
while IFS= read -r f; do
  if { case "$f" in docs/*) true ;; *) false ;; esac || in_list "$f" ${to_docs[@]+"${to_docs[@]}"}; } \
     && ! in_list "$f" ${to_impl[@]+"${to_impl[@]}"}; then
    docs+=("$f")
  else
    impl+=("$f")
  fi
done <<<"$changed"

[ ${#docs[@]} -eq 0 ] || [ -n "$docs_msg" ] || { echo "rebuild.sh: documentation changes need --docs-msg" >&2; exit 2; }
[ ${#impl[@]} -eq 0 ] || [ -n "$impl_msg" ] || { echo "rebuild.sh: implementation changes need --impl-msg" >&2; exit 2; }

echo "pre-rebuild=$pre"
done=
trap '[ -n "$done" ] || echo "rebuild.sh: stopped mid-rebuild; nothing pushed. Restore with: git reset --hard $pre" >&2' EXIT
run git reset -q --soft "origin/$base"
run git reset -q
if [ ${#docs[@]} -gt 0 ]; then
  run git add -A -- "${docs[@]}"
  run git commit -q -F "$docs_msg"
fi
if [ ${#impl[@]} -gt 0 ]; then
  run git add -A -- "${impl[@]}"
  run git commit -q -F "$impl_msg"
fi

if run git diff --quiet "$pre" HEAD; then
  done=1
  echo "content identical"
  run git log --oneline "origin/$base..HEAD"
else
  echo "rebuild.sh: content differs from $pre" >&2
  exit 1
fi
