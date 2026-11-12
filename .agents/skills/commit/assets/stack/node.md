# Node (npm, pnpm, Yarn; TypeScript, React, Astro and other Node toolchains)

## Scratch paths

Never staged: `node_modules/`, `.pnpm-store/`, `coverage/`, and framework build or cache output that git does not track (`dist/`, `.astro/`, `.next/`, `.turbo/`, `.svelte-kit/`).

## Quality gates

- Format fix: the formatter's write mode, usually `prettier --write .` or a `format` script in `package.json` (the checking form is `prettier --check .`).
- Suppression forms, never added on your own initiative: `// eslint-disable…` comments, `@ts-ignore` / `@ts-expect-error`, a file added to an ignore list (`.eslintignore`, `ignores:` in the ESLint config, `.prettierignore`), a rule turned `off`.
- Documentation-only fast path: Markdown or MDX inside the source tree that the build reads (content collections such as `src/content/`, MDX pages, a docs site) is a build input even when the `build-input docs` fact names nothing. A change to it runs the gates.

## Dependency registry

| Manifest | Publish date of `<x.y.z>` | Source repository |
|---|---|---|
| `package.json` | `curl -s https://registry.npmjs.org/<name> \| jq -r '.time["<x.y.z>"]'` (or `pnpm view <name> time --json \| jq -r '."<x.y.z>"'`) | `curl -s https://registry.npmjs.org/<name> \| jq -r '.repository.url // .homepage'` (or `pnpm view <name> repository.url maintainers`) |

A lockfile change alone (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`) with no `package.json` change is not a new dependency; a new direct dependency always shows in `package.json`.

Record: `package.json` cannot hold comments, so the record goes where the dependency policy says (a table such as `docs/dependencies.md` is common); if it says nothing, ask once, as the reference describes.

Project policy this asset applies **only when the dependency policy says so**: versions are exact. Under that rule a range in the new entry (`^`, `~`, `*`, `latest`, `x`) is a blocker; the package manager's save-prefix setting (for example `savePrefix: ''` in `pnpm-workspace.yaml`, or `save-exact=true` in `.npmrc`) is how the project keeps them exact.
