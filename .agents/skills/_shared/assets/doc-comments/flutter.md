# Flutter / Dart

## Doc comments

- Dartdoc: `///` line comments, never `/** … */` or a plain `//` where a doc
  comment is meant.
- Link identifiers in square brackets (`[CartState.empty]`, `[cartStateFor]`), so
  `dart doc` flags a renamed symbol.
- `// @spec AUTH-001` tags are plain `//` comments on the line before the
  `test(...)` call, never `///`.
- Generated files (`*.g.dart`, `*.freezed.dart`, generated localizations) get
  no doc comments and no findings.

```dart
// Bad — paraphrases the method name
/// Returns the cart state.
CartState cartStateFor(String userId) {}

// Good — explains the contract
/// Returns [CartState.empty] until the first item is added, and
/// [CartState.locked] while a checkout for [userId] is in progress.
CartState cartStateFor(String userId) {}
```
