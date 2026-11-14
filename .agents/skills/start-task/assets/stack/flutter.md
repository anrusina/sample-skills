# Flutter

## Setup

The usual steps a fresh Flutter worktree needs, in order. Propose only the ones
this repository shows a sign of; run them through the wrapper.

| Step | Command | Sign it applies |
|---|---|---|
| Packages | `flutter pub get` | always |
| Code generation | `dart run build_runner build` (add `--workspace` in a pub workspace: a `workspace:` list in the root `pubspec.yaml`) | `build_runner` in `dev_dependencies`, or `part '*.g.dart'` lines in the sources |
| Localizations | `flutter gen-l10n` | an `l10n.yaml` at the root, or `generate: true` under `flutter:` in `pubspec.yaml` |

Generated files are git-ignored, so the analyzer and the tests fail in a
worktree that skipped these steps.
