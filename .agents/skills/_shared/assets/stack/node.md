# Node

## Setup

Install with the lockfile frozen, by the lockfile at the repo root, through
the wrapper:

| Lockfile | Command |
|---|---|
| `pnpm-lock.yaml` | `pnpm install --frozen-lockfile` |
| `package-lock.json` | `npm ci` |
| `yarn.lock` | `yarn install --immutable` |

If the install fails, stop and report it. Never drop the frozen flag (or swap
`npm ci` for `npm install`) to make it pass: that installs versions nobody
reviewed.

## Re-run

Reinstall when `package.json` or the lockfile changed.
