# Assets

Load each asset whose condition holds at the start of the run. Each file's
H2 sections are named after the steps that apply them:

| Section | Applied in |
|---|---|
| *After rebase* | phase 1a steps 2–3: conflict rules while rebasing; re-run triggers (which may only skip a setup step the rebase left untouched) and checks once it finishes |
| *Unique identifiers* | phase 1a step 4, beside the EARS spec ID check |
| *Rebuild* | phase 2: which bucket a file goes in (passed to `rebuild.sh` as `--to-docs` or `--to-impl`), commit message rules |
| *Follow-up issues* | phase 4: labels and body details |
| *Summary* | phase 5: extra summary rows |
| *Worktree cleanup* | phase 5: notes on removing the worktree |

| Kind | Id | Applies when | Provides here |
|---|---|---|---|
| stack | `flutter` | `pubspec.yaml` at the repo root | which rebased files mean re-running code generation and localization |
| stack | `node` | `package.json` at the repo root | lockfile conflicts, reinstall when the lockfile changed, dependency records ride with the manifest |
| stack | `python` | `pyproject.toml`, `requirements*.txt` or `setup.py` at the repo root | reinstall when requirements changed; virtual environments on worktree removal |
| field | `accessibility` | AGENTS.md has accessibility rules (a section, or WCAG named) | label and criterion for accessibility follow-ups |
| field | `i18n` | the project ships more than one locale, or AGENTS.md has localisation rules (translation files, no hard-coded strings) | locale-file conflicts, duplicate and dangling keys, keys that ride with the docs commit |
| field | `frontend-ui` | the project has a user interface with a theme or design tokens, or AGENTS.md has layout or theming rules | token-file conflicts, design tokens that ride with the docs commit |
| field | `generated-artifacts` | build outputs are committed alongside their sources (whatever AGENTS.md calls them) | conflicts on outputs, regeneration, outputs travelling with their sources |
| field | `fonts` | the project **builds** fonts from sources (glyph drawings, manifests, code points); bundling or using fonts does not qualify | code points as a registry, manifest conflicts, glyph bullets and summary row |
