# Flutter / Dart

## Doc comments

- Dartdoc: `///` line comments, never `/** … */` or a plain `//` where a doc
  comment is meant.
- Link identifiers in square brackets (`[CellState.done]`, `[stateAt]`), so
  `dart doc` flags a renamed symbol.
- `// @spec AUTH-001` tags are plain `//` comments on the line before the
  `test(...)` call, never `///`.
- Generated files (`*.g.dart`, `*.freezed.dart`, generated localizations) get
  no doc comments and no findings.

```dart
// Bad — paraphrases the method name
/// Returns the cell state.
CellState stateAt(int row, int col) {}

// Good — explains the contract
/// Returns [CellState.done] once the user confirms the selection,
/// [CellState.highlighted] while the symbol is active in the legend.
CellState stateAt(int row, int col) {}
```
