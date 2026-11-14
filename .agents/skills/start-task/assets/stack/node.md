# Node

## Setup

A fresh Node worktree has no `node_modules/`. Propose the install that matches
the lockfile at the repo root; run it through the wrapper.

| Lockfile | Command |
|---|---|
| `pnpm-lock.yaml` | `pnpm install --frozen-lockfile` |
| `package-lock.json` | `npm ci` |

If the install fails, stop and report it. Never drop `--frozen-lockfile` (or
swap `npm ci` for `npm install`) to make it pass: that rewrites the lockfile
and installs versions nobody reviewed.
