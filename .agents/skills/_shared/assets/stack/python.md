# Python

## Setup

A fresh worktree has no virtual environment. Most projects' first gate
creates one (a `make` target, `tox`, `nox`); when it doesn't, suggest one
installed from the requirements file(s), or from `pyproject.toml` when there
is none:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt   # or: .venv/bin/pip install -e .
```

A failed install is a setup gap, not a finding: report it.

## Re-run

Reinstall into each virtual environment, the way the *setup* fact installs
it, when `requirements*.txt`, `pyproject.toml`, `setup.py` or a lockfile
changed.
