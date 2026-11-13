# Project pre-merge checks (phase 1b)

Read this only when the *pre-merge checks* fact is set. Run every check it
lists, in its order, on the rebased branch, and put each one's result in the
phase 5 summary.

Every command below runs from the worktree; `<base>`, `<N>` and the
wrapper are the values the skill already worked out.

## Conditional checks

A check that applies only when the branch touches certain paths (a native
build after a toolchain change, say) runs only when one of them changed:

```bash
git diff --name-only origin/<base>...HEAD
```

For a file where only some lines count (a manifest whose version line the
bump below changes, say), look at which lines changed in the branch diff. If
nothing on the list is touched, say so in one line.

## Local suites

Run the command the fact gives. A failure stops the merge, as a gate does.
If a suite reads git-ignored fixtures that live only in the primary
checkout, link each fixture folder the fact names into this worktree first:

```bash
root=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
[ -e "<folder>" ] || [ ! -d "$root/<folder>" ] || ln -s "$root/<folder>" "<folder>"
```

If the primary checkout lacks a fixture folder, stop and name it. The merge
waits for a run where the fixtures are, unless the developer says in chat to
merge without them; then record `<suite>: not run (no <folder> on this
machine)` in the PR description and in the summary. The links are untracked
files; `rebuild.sh` commits only files the branch changed, so they never
reach a commit.

## Checks the developer runs by hand

A workflow started by hand, a test on a device: ask the developer whether it
has passed on this branch, and stop until they confirm.

## Version bump

Every merge raises the version once, counted from the version the default
branch holds now, or from the latest release tag's when the *releases* fact
says releases are tagged and that is higher (a hotfix can release a version
the default branch never held).

| Level | When |
|---|---|
| `minor` | the branch name starts `feature-`, or any commit on it is a `feat:` |
| `patch` | anything else: a backward-compatible fix or maintenance |
| `major` | only when the developer asks for it in this run; never inferred |

Find the commit types with `git log origin/<base>..HEAD --format=%s`. Run the
bump command the fact gives, at that level and counting from
`origin/<base>`, then commit only if a file the bump writes changed (an
untracked fixture link must not count), all in one call:

```bash
<the bump command from the fact, at <level>, from origin/<base>>
if ! git diff --quiet -- <the files the bump writes>; then
  git add -- <the files the bump writes>
  msg=$(mktemp)
  cat > "$msg" <<'MSG_EOF'
[#<issue>] chore: raise the version to <new version>
MSG_EOF
  git commit -q -F "$msg"
  rm -f "$msg"
fi
```

Run again on the same default branch, it computes the same version and finds
nothing to commit; run after the default branch moved, it bumps from the new
version. A rebase conflict on the version was already settled in phase 1a.
Phase 2 folds this commit into the implementation commit.

## Other checks that change files

Release notes, a status table: commit them on the branch, the same way, so
phase 2 sorts them into its buckets.

## CI-equivalent run

A workflow that runs the gates on a clean checkout must run on the history
phase 2 pushes, so phase 2 starts it after its push, not now:

1. If every changed path is Markdown, or under `docs/`, `.agents/` or
   `.claude/`, and none is a build input by the *build-input docs* fact,
   skip it and say so in one line.
2. Otherwise phase 2 runs `ci-run.sh` (the command is in SKILL.md). It
   uses the run already on the head commit, or starts one, waits, and
   prints `run=` and `conclusion=` (with the failing steps' log on any
   conclusion but `success`).
3. Only `success` lets the merge go on.
   - `cancelled`: a newer run may have replaced it, or someone cancelled it.
     Run the script again, which takes the newest run on the head commit; if
     that one was cancelled too, run it once more with `--new`. If the run
     it started is cancelled as well, **stop** and ask the developer.
   - Anything else (`failure`, `timed_out`, `startup_failure`,
     `action_required`, …): show the log tail it printed and **stop**. Fix
     it on the branch and re-run `/pre-merge`.
