# Python

## Setup

A fresh worktree has no virtual environment. Create one and install into it,
from each requirements file the build section's commands rely on (one venv
per file, when the project keeps separate environments), or from
`pyproject.toml` when there is none, unless the first gate run creates it:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt   # or: .venv/bin/pip install -e .
```

A failed install is a setup gap, not a finding: report it.

## Re-run

Reinstall into each virtual environment, the way the *setup* fact installs
it, when `requirements*.txt`, `pyproject.toml`, `setup.py` or a lockfile
changed.
