# start-task assets

Load every asset whose condition holds; the step that uses a section names it.
Each is consulted only when AGENTS.md has no *Worktree setup*: its steps are
proposed to the developer to run and to record there, never run unasked.

| Kind | Id | Applies when (generic copy) | Provides here |
|---|---|---|---|
| stack | [`flutter`](stack/flutter.md) | `pubspec.yaml` at the repo root | *Setup*: the usual fresh-worktree steps (packages, code generation, localizations) |
| stack | [`node`](stack/node.md) | `package.json` at the repo root | *Setup*: the frozen-lockfile install for the package manager in use |
| stack | [`python`](stack/python.md) | `pyproject.toml`, `requirements*.txt` or `setup.py` at the repo root | *Setup*: a virtual environment and the requirements install |
