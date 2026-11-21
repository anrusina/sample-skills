# Python

## After rebase

Run what the *Re-run* section of [../../../_shared/assets/stack/python.md](../../../_shared/assets/stack/python.md) says for the files phase 1a step 3 listed. If an install fails, stop and report it rather than continuing with the old packages.
## Worktree cleanup

`git worktree remove` also deletes the worktree's git-ignored virtual
environments (`.venv*/`); no separate step is needed.
