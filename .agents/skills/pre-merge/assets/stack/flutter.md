# Flutter / Dart

## After rebase

Code generation and localization output is usually git-ignored, so the
rebase can leave it stale with no sign in `git status`. Match the files
phase 1a step 3 listed against these triggers, and run the matching steps
the *setup* fact names (for example `dart run build_runner build` and
`flutter gen-l10n`, through the wrapper):

| Changed file | Run |
|---|---|
| `pubspec.yaml` or `pubspec.lock` (any package in a workspace) | the dependency get, then code generation and localization |
| a `.dart` file with a `part '….g.dart'` (or `.freezed.dart`, `.gr.dart`) directive | code generation |
| an `.arb` file | localization |

Find the Dart files with a generated part:
```bash
git diff --name-only <pre-rebase-sha> HEAD -- '*.dart' \
  | while read -r f; do grep -lE "^part '.*\.(g|freezed|gr)\.dart'" "$f" 2>/dev/null; done
```

When in doubt, run both: stale output fails only later, in the gates or at
run time.
