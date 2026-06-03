# Documentation conventions

Write for the developer who needs to understand intent, not implementation.

| Rule | What it means |
|---|---|
| Purpose over paraphrase | Explain *what* and *why*; the code says *how* |
| Concrete over abstract | Real file paths, real spec IDs, real Dart identifiers |
| Short over thorough | A sentence that is read beats a paragraph that is skipped |

## Dart doc comment style

```dart
// Bad — paraphrases the method name
/// Returns the cell state.
CellState stateAt(int row, int col) {}

// Good — explains the contract
/// Returns [CellState.done] once the user confirms the selection,
/// [CellState.highlighted] while the symbol is active in the legend.
CellState stateAt(int row, int col) {}
```

## Mermaid diagrams

Use `flowchart LR` for data flows; `flowchart TD` for hierarchies; `sequenceDiagram` for call sequences.

## Anti-patterns

| Anti-pattern | Fix |
|---|---|
| Paraphrasing the signature | Explain the business contract, or remove the comment |
| Documenting the obvious | Remove it |
| Vague summaries | Name the specific behaviour |
| ASCII art diagrams | Replace with Mermaid |
