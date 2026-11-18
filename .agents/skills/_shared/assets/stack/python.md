# Python

## Setup

A fresh worktree has no virtual environment:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Use each requirements file the build section's commands rely on (one venv
per file, when the project keeps separate environments). If an install
fails, stop and report it as a setup gap, not a finding.

## Re-run

Reinstall into each virtual environment, the way the *setup* fact installs
it, when `requirements*.txt`, `pyproject.toml`, `setup.py` or a lockfile
changed.
