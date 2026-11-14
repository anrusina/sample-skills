# Python

## Worktree setup

- Dependencies live in a virtual environment the build creates from `requirements*.txt` or `pyproject.toml` (for example `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt`, or the first gate run creates it). An install failure is a setup gap, not a finding.
- The virtual environment survives a checkout. On a reused worktree, re-install only if `git diff --name-only <prev-sha>..<head-sha>` touches `requirements*.txt`, `pyproject.toml` or a lockfile.

## Gates

- Do not assume a formatter, linter or test runner: run only what the *gates* fact names. Where a formatter is among them, use its check mode (`black --check`, `ruff format --check`).

## Review checks

- Determinism, where the project's output must be reproducible: build output that depends on a timestamp, the current locale or time zone, iteration over a `set`, `os.listdir()` or `glob()` without sorting, or an unseeded random source. A dependency bump that changes output bytes is a finding unless the PR says so.
- A dependency added to or upgraded in `requirements*.txt` or `pyproject.toml` without the policy check AGENTS.md requires
- A mutable default argument; a bare `except:` or `except Exception:` that swallows the error; a file or process opened without `with` on a path that can raise
- Suppression syntax for *Not findings*: `# noqa: <code>`, `# type: ignore[<code>]`, `# pragma: no cover`, plus any exemption marker AGENTS.md defines

## Inline comments

- Suggestion snippets in Python.
