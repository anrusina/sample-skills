# Node (TypeScript, React, Astro and other Node toolchains)

## Worktree setup

- Install dependencies with the lockfile frozen, in the package manager the lockfile belongs to: `pnpm install --frozen-lockfile`, `npm ci` or `yarn install --immutable`. Never drop the frozen flag: a review must build what the PR pins.
- On a reused worktree, re-install only if `git diff --name-only <prev-sha>..<head-sha>` touches `package.json` or the lockfile.

## Gates

- Formatter in check mode: `prettier --check .` (never `--write`), or the check target AGENTS.md names.

## Review checks

- TypeScript: `any`, an `as` cast or a non-null `!` on a value that can in fact be another type or absent; a type widened to silence an error
- React: an effect with missing or over-broad dependencies; an effect that subscribes, listens or starts a timer with no cleanup function; state set after unmount or after a superseded request; a list rendered without stable `key`s
- Astro: a `client:*` directive outside the folder AGENTS.md reserves for islands, or a page hydrated where static HTML would do; one island per interactive composition; `getStaticPaths()` and locale handling that misses a locale or a fallback; images not served through `astro:assets` with `widths` and `sizes` where the project uses it
- Dependencies: a version range (`^`, `~`, `*`, `latest`) where the project's dependency policy requires exact versions
- Suppression syntax for *Not findings*: `// eslint-disable-next-line <rule>`, `/* eslint-disable <rule> */`, `// @ts-expect-error`, `// @ts-ignore`, plus any exemption marker AGENTS.md defines. A suppression that names no rule, or `@ts-ignore` where `@ts-expect-error` would do, is a finding.

## Inline comments

- Suggestion snippets in TypeScript, TSX, Astro or CSS, matching the changed file.
