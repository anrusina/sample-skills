# Node (TypeScript, React, Astro and other Node toolchains)

## After rebase

- **Lockfile conflicts.** Never hand-merge a lockfile. Resolve
  `package.json` first, take either side of the lockfile, and regenerate it
  with the package manager's install once the rebase finishes; stage the
  result in the commit that resolves the conflict.
- **Re-run trigger.** When the files phase 1a step 3 listed include the
  lockfile (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`), reinstall
  with the frozen form the *setup* fact uses: `pnpm install
  --frozen-lockfile`, `npm ci`, or `yarn install --immutable`. Never drop the
  frozen flag to make an install pass: a mismatch is a lockfile/manifest
  conflict to resolve.

## Rebuild

A dependency record under `docs/` (the table of checked dependency
versions) rides with its manifest: when `package.json` changed, pass the
record's file to `rebuild.sh` as `--to-impl <file>`.
