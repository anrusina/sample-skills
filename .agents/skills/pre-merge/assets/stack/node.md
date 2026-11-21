# Node (TypeScript, React, Astro and other Node toolchains)

## After rebase

- **Lockfile conflicts.** Never hand-merge a lockfile. Resolve
  `package.json` first, take either side of the lockfile, and regenerate it
  with the package manager's install once the rebase finishes; stage the
  result in the commit that resolves the conflict.
- **Re-run.** Run what the *Re-run* section of
  [../../../_shared/assets/stack/node.md](../../../_shared/assets/stack/node.md)
  says for the files phase 1a step 3 listed, in its *Setup* form. A
  frozen-install mismatch is a lockfile/manifest conflict to resolve.

## Rebuild

A dependency record under `docs/` (the table of checked dependency
versions) rides with its manifest: when `package.json` changed, pass the
record's file to `rebuild.sh` as `--to-impl <file>`.
