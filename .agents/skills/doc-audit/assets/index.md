# Assets

At the start of the run, load every asset whose condition holds (a project
copy holds only the ones that apply), and apply each where a step names its
section. An asset without that section adds nothing there.

| Asset | Applies when | Provides here |
|---|---|---|
| `stack/flutter.md` | `pubspec.yaml` at the repo root | *Doc comments*: dartdoc `///` style, bracket links, example |
| `stack/node.md` | `package.json` at the repo root | *Doc comments*: TSDoc style, example; *Docs checks*: dependency record matches `package.json` |
| `stack/python.md` | `pyproject.toml`, `requirements*.txt` or `setup.py` at the repo root | *Doc comments*: docstring style, example |
| `field/accessibility.md` | AGENTS.md has accessibility rules (a section, or WCAG named) | *Docs checks*: keyboard path, landmarks and names in specs match the markup |
| `field/i18n.md` | the project ships more than one locale, or AGENTS.md has localisation rules (translation files, no hard-coded strings) | *Docs checks*: translation keys a spec names exist |
| `field/frontend-ui.md` | the project has a user interface with a theme or design tokens, or AGENTS.md has layout or theming rules | *LLD checks*: catalog failure states |
| `field/web-site.md` | the project is a public web site with rules for search, links, product claims or a performance budget (a web *app* without them doesn't qualify) | *Docs checks*: product claims match AGENTS.md's product facts |
| `field/generated-artifacts.md` | build outputs are committed alongside their sources (whatever AGENTS.md calls them) | *Docs checks*: skip generated outputs; stale output paths |
