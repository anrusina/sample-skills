# Python

## Scratch paths

Never staged: `.venv*/` and `venv/` (every local virtual environment), `__pycache__/`, `*.pyc`, `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`, `.tox/`, `*.egg-info/`.

## Quality gates

- Format fix: the formatter's write mode, when the gate runs it in check mode (`ruff format`, `black .`, `ruff check --fix`).
- Suppression forms, never added on your own initiative: `# noqa`, `# type: ignore`, `# pragma: no cover`, a rule or path added to an ignore list in `pyproject.toml` / `setup.cfg`, a warning filter that hides a build warning.

## Dependency registry

| Manifest | Publish date of `<x.y.z>` | Source repository |
|---|---|---|
| `pyproject.toml`, `requirements*.txt` | `curl -s https://pypi.org/pypi/<name>/<x.y.z>/json \| jq -r '.urls[0].upload_time_iso_8601'` | `curl -s https://pypi.org/pypi/<name>/json \| jq '.info.project_urls'` (look for Source / Repository / Homepage) |

Record: a `# Checked <today>: …` comment directly above the dependency line (both TOML and `requirements.txt` take `#` comments).
