# Flutter

## Setup

The steps a fresh worktree needs, in order. Take only the ones this
repository shows a sign of, and run them through the wrapper.

| Step | Command | Sign it applies |
|---|---|---|
| Packages | `flutter pub get` | always |
| Code generation | `dart run build_runner build` (add `--workspace` in a pub workspace: a `workspace:` list in the root `pubspec.yaml`) | `build_runner` in `dev_dependencies`, or `part '*.g.dart'` lines in the sources |
| Localizations | `flutter gen-l10n` | an `l10n.yaml` at the root, or `generate: true` under `flutter:` in `pubspec.yaml` |

Generated code and localizations are usually git-ignored: analyzer errors
from unresolved generated files mean a step is missing, not a finding.

## Re-run

A change to these files makes a step stale (`git diff --name-only <old> <new>`):

| Changed file | Run |
|---|---|
| `pubspec.yaml` or `pubspec.lock` (any package in a workspace) | packages, then code generation and localizations |
| a `.dart` file with a `part '….g.dart'` (or `.freezed.dart`, `.gr.dart`) directive | code generation |
| an `.arb` file | localizations |

Find the Dart files with a generated part:
```bash
git diff --name-only <old> <new> -- '*.dart' \
  | while read -r f; do grep -lE "^part '.*\.(g|freezed|gr)\.dart'" "$f" 2>/dev/null; done
```

When in doubt, run both.
