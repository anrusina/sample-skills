# Flutter / Dart

## Worktree setup

- Generated code (code generation such as `build_runner`, localisation output from `flutter gen-l10n`) is usually git-ignored, so a fresh worktree needs the *setup* steps before `dart analyze` means anything. Analyzer errors from unresolved generated files are a setup gap, not findings.
- On a reused worktree, re-run code generation only if `git diff --name-only <prev-sha>..<head-sha>` touches `pubspec.yaml`, `pubspec.lock` or a `.dart` file with a `part '….g.dart'` directive; re-run localisation generation only if it touches a `.arb` file. Re-run `flutter pub get` when the pubspec or lockfile changed.

## Gates

- Formatter in check mode: `dart format --output=none --set-exit-if-changed .`
- The analyzer gate is `dart analyze`, not `flutter analyze`: only `dart analyze` runs analyzer plugins (custom lint rules such as `riverpod_lint`), so `flutter analyze` can pass on code the real gate rejects. Use the flags the *gates* fact gives (`--fatal-infos`, for example).

## Review checks

- A `StreamSubscription`, `AnimationController`, `TextEditingController`, `ScrollController`, `FocusNode`, `Timer` or listener created in a `State` (or a state holder) and not cancelled or disposed in `dispose()`
- Expensive work in `build()`: I/O, parsing, sorting, large allocations, or creating a controller or future there, so it repeats on every rebuild (a `FutureBuilder` whose future is created in `build()` refires every rebuild)
- Rebuilds broader than needed: a whole widget watching a provider or listenable when it reads one field (no `select`), a missing `const` constructor on a static subtree
- `setState` (or any use of `context`) after an `await` without a `mounted` check, or after `dispose`
- Suppression syntax for *Not findings*: `// ignore: <rule>` and `// ignore_for_file: <rule>`, plus any exemption marker AGENTS.md defines

## Inline comments

- Suggestion snippets in Dart.
