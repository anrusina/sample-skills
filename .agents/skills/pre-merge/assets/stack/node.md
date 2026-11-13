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
  frozen flag to make an install pass; a mismatch means the lockfile and
  manifest disagree, and that is a conflict to resolve.

## Rebuild

A dependency record that lives under `docs/` (a table of dependencies with
the date each version was checked, kept there because JSON manifests cannot
hold comments) rides with its manifest: when `package.json` changed, the
record's file goes in the implementation bucket with the manifest and
lockfile, not in the docs commit: pass it to `rebuild.sh` as
`--to-impl <file>`.
