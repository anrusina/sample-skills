# review-pr assets

Load every asset whose condition holds at the start of the run. Each file has
H2 sections named after the step that applies them:

- *Worktree setup* — phase 0: setup notes and the inputs that make a reused worktree re-run a step
- *Gates* — phase 0: the check-only form of a gate, and gate pitfalls
- *Review checks* — step 6 (and 5a, 8): the checks, what to read, severity floors, suppression syntax
- *Inline comments* — step 10: the snippet language, a closing line for the prompt, blast-radius examples
- *Verification* — step 11: extra rows for the summary's Verification table

An asset without a section adds nothing at that step.

| Kind | Id | Applies when (generic copy) | Provides here |
|---|---|---|---|
| stack | `flutter` | `pubspec.yaml` at the repo root | code-generation re-run triggers, `dart analyze` over `flutter analyze`, widget lifecycle and `build()` checks, Dart snippets |
| stack | `node` | `package.json` at the repo root | frozen-lockfile install, TypeScript, React and Astro checks, `eslint-disable` syntax, TS/TSX snippets |
| stack | `python` | `pyproject.toml`, `requirements*.txt` or `setup.py` at the repo root | virtual-environment setup, deterministic output and Python checks, `# noqa` syntax, Python snippets |
| field | `accessibility` | AGENTS.md has accessibility rules (a section, or WCAG named) | the project's accessibility rules and checklist, WCAG severity floors, a manual-check row |
| field | `i18n` | the project ships more than one locale, or AGENTS.md has localisation rules (translation files, no hard-coded strings) | copy in translation files, source-locale keys, severity floor for hard-coded copy |
| field | `frontend-ui` | the project has a user interface with a theme or design tokens, or AGENTS.md has layout or theming rules | values outside the theme layer, every theme, the listed widths |
| field | `web-site` | the project is a public web site with rules for search, links, product claims or a performance budget (a web *app* without them doesn't qualify) | indexing, search fields, links, third-party requests, the performance budget |
| field | `generated-artifacts` | build outputs are committed alongside their sources (whatever AGENTS.md calls them) | outputs changed with their sources, never reviewed line by line |
| field | `fonts` | the project **builds** fonts from sources (glyph drawings, manifests, code points); bundling or using fonts does not qualify | glyph standards, code points as permanent public identifiers, looking at the glyphs |
