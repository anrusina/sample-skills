# Python

## Worktree setup

The *Setup* and *Re-run* sections of [../../../_shared/assets/stack/python.md](../../../_shared/assets/stack/python.md), with `<prev-sha>` and `<head-sha>` for a reused worktree.

## Gates

- Do not assume a formatter, linter or test runner: run only what the *gates* fact names. Where a formatter is among them, use its check mode (`black --check`, `ruff format --check`).

## Review checks

- Determinism, where the project's output must be reproducible: build output that depends on a timestamp, the current locale or time zone, iteration over a `set`, `os.listdir()` or `glob()` without sorting, or an unseeded random source. A dependency bump that changes output bytes is a finding unless the PR says so.
- A dependency added to or upgraded in `requirements*.txt` or `pyproject.toml` without the policy check AGENTS.md requires
- A mutable default argument; a bare `except:` or `except Exception:` that swallows the error; a file or process opened without `with` on a path that can raise
- Suppression syntax for *Not findings*: `# noqa: <code>`, `# type: ignore[<code>]`, `# pragma: no cover`, plus any exemption marker AGENTS.md defines

## Inline comments

- Suggestion snippets in Python.
