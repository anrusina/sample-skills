# Python

## After rebase

When the files phase 1a step 3 listed include `requirements*.txt`,
`pyproject.toml` or `setup.py`, reinstall into each virtual environment the
*setup* fact names, the way it installs them (for example
`.venv/bin/pip install -r requirements.txt`). An install failure is a setup
gap: stop and report it rather than continuing with the old packages.

## Worktree cleanup

`git worktree remove` also deletes the worktree's virtual environments
(`.venv*/`): they are git-ignored, so they do not block the removal and need
no separate step.
