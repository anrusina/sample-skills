# Generated artifacts (build outputs committed with their sources)

Read from AGENTS.md: which outputs are committed, the command that lists their
build inputs (if it names one), and the command that regenerates the outputs
(usually part of the gates).

## Staging

- **Outputs travel with their sources.** When a build input changes, the
  regenerated outputs belong in the same commit; step 5 regenerates them.
- When something is already staged, unstaged changes to build inputs are the
  one exception to "leave unstaged changes alone": they stop the commit at
  step 5 (*Before the gates*).

## Split check

| Signal | Action |
|---|---|
| Build inputs + the outputs regenerated from them | Single commit |
| A build tool change + the outputs it regenerates | Single commit |

## Before the gates

Check that the working tree holds no build input this commit leaves out: a
gate that builds from the working tree would put it into the committed
outputs while the input itself stays out. With AGENTS.md's input-listing
command in place of `<list inputs>`:

```bash
git diff --name-only -- $(<list inputs>)
git ls-files --others --exclude-standard -- $(<list inputs>)
```

Use the command substitution directly, not a variable (zsh does not split an
unquoted variable). If either command prints a path, stop: report the paths
and ask the developer to stage them or set them aside; do not stash them
yourself.

## Gate results

- **Generated outputs out of date** (the gate rebuilt outputs that differ from
  what is staged): if their sources are in this commit, stage the listed
  outputs with `git add <path>...` and run the gates again. If no source in
  this commit explains the change, stop and report the outputs as stale
  before this work.
- A regeneration AGENTS.md runs only when a particular tool changes (a
  template or sample rebuild, say): when that tool is in the commit, run it
  too and stage what it regenerates.
