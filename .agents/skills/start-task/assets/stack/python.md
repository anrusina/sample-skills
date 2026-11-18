# Python

## Setup

A fresh Python worktree has no virtual environment. Propose:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Use each requirements file the build section's commands rely on (one venv per
file, when the project keeps separate environments). If the install fails,
stop and report it as a setup gap.
