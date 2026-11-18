# Generated artifacts (committed build outputs)

## After rebase

- **Conflicts on outputs.** Never merge a generated file by hand. Take
  either side (`git checkout --theirs -- <path>`), finish resolving the
  sources, then regenerate with the command AGENTS.md gives and stage the
  result before `git rebase --continue`.
- **After the rebase.** Regenerate once more and check that the output paths
  AGENTS.md names are unchanged (`git status --porcelain -- <output paths>`
  prints nothing). On a difference, commit the regenerated files on the
  branch before the gates run.

## Rebuild

Outputs ride with their sources: each generated file goes in the same
commit as the source files it is built from, never split across the docs
and implementation commits. A conditional pre-merge check that regenerates
committed output must leave the tree unchanged; on a difference, stop and
report the stale output.
