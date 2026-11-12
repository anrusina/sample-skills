# commit assets

Load every asset whose condition holds at the start of the run (see the
skill's *Project facts*). Each step names the asset section it applies.

| Kind | Id | Applies when (generic copy) | Provides here |
|---|---|---|---|
| stack | `flutter` | `pubspec.yaml` at the repo root | scratch paths, format fix and suppression forms, pub.dev registry row |
| stack | `node` | `package.json` at the repo root (covers TypeScript, React, Astro and other Node toolchains) | scratch paths, format fix and suppression forms, Markdown that counts as a build input, npm registry row, the exact-versions policy when the project sets it |
| stack | `python` | `pyproject.toml`, `requirements*.txt` or `setup.py` at the repo root | scratch paths (local venvs), format fix and suppression forms, PyPI registry row |
| stack | `rust` | `Cargo.toml` at the repo root | scratch paths, format fix and suppression forms, crates.io registry row |
| stack | `go` | `go.mod` at the repo root | scratch paths, format fix and suppression forms, Go module proxy row |
| stack | `jvm` | `pom.xml` or `build.gradle*` at the repo root | scratch paths, format fix and suppression forms, Maven Central row |
| stack | `ruby` | `Gemfile` or a `*.gemspec` at the repo root | scratch paths, format fix and suppression forms, RubyGems row |
| field | `generated-artifacts` | build outputs are committed alongside their sources (whatever AGENTS.md calls them) | outputs travel with their sources, unstaged-input check before the gates, stale-output stop |
| field | `fonts` | the project **builds** fonts from sources (glyph drawings, manifests, code points); bundling or using fonts does not qualify | glyph-geometry warnings block, commit bullets name code points |
| field | `web-site` | the project is a public web site with rules for search, links, product claims or a performance budget (a web *app* without them doesn't qualify) | the `content` commit type and branch prefix |

Sections used: *Scratch paths* (step 1), *Staging* (step 1), *Commit message*
(steps 2 and 8), *Split check* (step 3), *Dependency registry* (step 4),
*Quality gates*, *Before the gates*, *Gate results* (step 5).
