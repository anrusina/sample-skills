# Assets

At the start of the run, load every asset whose condition holds (a project
copy holds only the ones that apply), and apply each where a step names its
section. An asset without that section adds nothing there. The `--review`
pass uses `/doc-audit`'s own assets.

| Asset | Applies when | Provides here |
|---|---|---|
| `stack/flutter.md` | `pubspec.yaml` at the repo root | *Doc comments*: dartdoc `///` style, bracket links, example |
| `stack/node.md` | `package.json` at the repo root | *Doc comments*: TSDoc style, example |
| `stack/python.md` | `pyproject.toml`, `requirements*.txt` or `setup.py` at the repo root | *Doc comments*: docstring style, example |
| `field/frontend-ui.md` | the project has a user interface with a theme or design tokens, or AGENTS.md has layout or theming rules | *Fix docs*: catalog lists in UI LLDs |
| `field/generated-artifacts.md` | build outputs are committed alongside their sources (whatever AGENTS.md calls them) | *Fix comments*: edit sources, never outputs; regenerate |
