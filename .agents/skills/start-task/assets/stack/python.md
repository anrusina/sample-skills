# Python

## Setup

A fresh Python worktree has no virtual environment. Propose:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Use each requirements file the build section's commands rely on; a project
with several environments (one venv per requirements file, say) needs one
venv per file. If the install fails, stop and report it as a setup gap.
