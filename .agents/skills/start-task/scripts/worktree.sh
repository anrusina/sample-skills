#!/usr/bin/env bash
# Create, move and remove the worktrees the skills work in. Every worktree
# sits directly under the primary checkout's .claude/worktrees/, never inside
# another worktree, wherever the session runs from.
#
# Usage: worktree.sh [--wrap '<prefix>'] <command> ...
#   root                       print the primary checkout's path
#   add <name> <ref> [--pr N]  fetch origin (and pull/N/head with --pr), then
#                              add a detached worktree at <ref> named
#                              <name>-<6 hex>; prints primary=<path> and
#                              worktree=<path>, and prints nothing on failure
#   move <worktree> <sha>      fetch origin, check the worktree out at <sha>;
#                              prints previous=<sha> (the commit it was on)
#   remove <path> [<branch>]   remove a worktree (git refuses one with
#                              uncommitted changes), delete <branch> with -D,
#                              and prune
#   remove-merged <pr> <base>  run inside a linked worktree after its PR
#                              merged: confirm MERGED, detach at origin/<base>,
#                              remove the worktree and delete its branch
set -euo pipefail

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2; exit 2; }
WRAP=()
if [ "${1:-}" = "--wrap" ]; then
  [ $# -ge 2 ] || usage
  read -r -a WRAP <<<"$2"; shift 2
fi
run() { ${WRAP[@]+"${WRAP[@]}"} "$@"; }
primary() { dirname "$(run git rev-parse --path-format=absolute --git-common-dir)"; }

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  root)
    [ $# -eq 0 ] || usage
    primary
    ;;
  add)
    [ $# -eq 2 ] || [ $# -eq 4 ] || usage
    name=$1 ref=$2 pr=
    if [ $# -eq 4 ]; then [ "$3" = "--pr" ] || usage; pr=$4; fi
    run git fetch -q origin
    [ -z "$pr" ] || run git fetch -q origin "pull/$pr/head"
    root=$(primary)
    mkdir -p "$root/.claude/worktrees"
    for _ in 1 2 3 4 5; do
      sfx=$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')
      wt="$root/.claude/worktrees/$name-$sfx"
      [ -e "$wt" ] && continue
      run git worktree add -q --detach "$wt" "$ref" >&2
      echo "primary=$root"
      echo "worktree=$wt"
      exit 0
    done
    echo "worktree.sh: no free path for $name after 5 tries" >&2
    exit 1
    ;;
  move)
    [ $# -eq 2 ] || usage
    run git fetch -q origin
    prev=$(run git -C "$1" rev-parse HEAD)
    run git -C "$1" checkout -q --detach "$2"
    echo "previous=$prev"
    ;;
  remove)
    [ $# -eq 1 ] || [ $# -eq 2 ] || usage
    root=$(primary)
    run git -C "$root" worktree remove "$1"
    [ $# -eq 1 ] || run git -C "$root" branch -D "$2"
    run git -C "$root" worktree prune
    ;;
  remove-merged)
    [ $# -eq 2 ] || usage
    state=$(run gh pr view "$1" --json state -q .state)
    if [ "$state" != MERGED ]; then
      echo "worktree.sh: PR #$1 is $state, not MERGED; nothing removed" >&2; exit 1
    fi
    if [ "$(run git rev-parse --absolute-git-dir)" = "$(run git rev-parse --path-format=absolute --git-common-dir)" ]; then
      echo "worktree.sh: this is the primary checkout, not a linked worktree; nothing removed" >&2; exit 1
    fi
    branch=$(run git branch --show-current)
    wt=$(run git rev-parse --show-toplevel)
    root=$(primary)
    run git fetch -q origin
    # Detached: another checkout may hold <base>. -D: a rebase merge gives the
    # commits new SHAs, so -d would refuse. -C: git won't remove the worktree
    # you stand in.
    run git switch -q --detach "origin/$2"
    run git -C "$root" worktree remove "$wt"
    [ -z "$branch" ] || run git -C "$root" branch -D "$branch"
    echo "removed $wt${branch:+ and branch $branch}"
    ;;
  *) usage ;;
esac
