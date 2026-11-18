# Flutter / Dart

## Worktree setup

The *Setup* and *Re-run* sections of [../../../_shared/assets/stack/flutter.md](../../../_shared/assets/stack/flutter.md), with `<prev-sha>` and `<head-sha>` for a reused worktree.

## Gates

- Formatter in check mode: `dart format --output=none --set-exit-if-changed .`
- The analyzer gate is `dart analyze`, not `flutter analyze`: only `dart analyze` runs analyzer plugins (custom lint rules such as `riverpod_lint`). Use the flags the *gates* fact gives (`--fatal-infos`, for example).

## Review checks

- A `StreamSubscription`, `AnimationController`, `TextEditingController`, `ScrollController`, `FocusNode`, `Timer` or listener created in a `State` (or a state holder) and not cancelled or disposed in `dispose()`
- Expensive work in `build()`: I/O, parsing, sorting, large allocations, or creating a controller or future there, so it repeats on every rebuild (a `FutureBuilder` whose future is created in `build()` refires every rebuild)
- Rebuilds broader than needed: a whole widget watching a provider or listenable when it reads one field (no `select`), a missing `const` constructor on a static subtree
- `setState` (or any use of `context`) after an `await` without a `mounted` check, or after `dispose`
- Suppression syntax for *Not findings*: `// ignore: <rule>` and `// ignore_for_file: <rule>`, plus any exemption marker AGENTS.md defines

## Inline comments

- Suggestion snippets in Dart.
