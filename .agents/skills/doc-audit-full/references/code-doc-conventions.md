# Documentation conventions

Write for the developer who needs to understand intent, not implementation.

These are the language-neutral rules `/doc-audit` and `/doc-audit-full` apply
to doc comments and diagrams. The doc-comment syntax, the identifier-linking
style and an example come from the *Doc comments* section of the loaded stack
asset (`assets/stack/<id>.md`).

| Rule | What it means |
|---|---|
| Purpose over paraphrase | Explain *what* and *why*; the code says *how* |
| Concrete over abstract | Real file paths, real spec IDs, real identifiers from the code |
| Short over thorough | A sentence that is read beats a paragraph that is skipped |

## Doc comment style

Use the language's standard doc-comment syntax — the one its documentation
tool and editors pick up — never a plain comment where a doc comment is meant.
With no stack asset loaded, that is the language's own convention (for example
`///` line comments, `/** … */` blocks, or docstrings).

- Doc comments go only on public API whose contract is non-obvious: what a
  caller must pass, what comes back in each case, what it guarantees or
  refuses.
- Open with one summary sentence that states the contract.
- Document parameters and return values as short fragments, with no
  trailing period on a fragment.
- Mark identifiers the way the language's doc tool links them, so renamed
  symbols are caught.
- No doc comments on trivial getters, test helpers, or generated code.

The shape of a good comment against a bad one, whatever the language:

- Bad: "Returns the cart total." — paraphrases the name.
- Good: "Sum of line prices after discounts, before tax and shipping. Zero for
  an empty cart; never negative, since a discount is capped at its line's
  price." — states the contract.

## Mermaid diagrams

Use `flowchart LR` for data flows; `flowchart TD` for hierarchies; `sequenceDiagram` for call sequences.

Node and edge labels use the names the code uses — classes, functions,
modules — so a rename shows up as a stale label.

## Anti-patterns

| Anti-pattern | Fix |
|---|---|
| Paraphrasing the signature | Explain the business contract, or remove the comment |
| Documenting the obvious | Remove it |
| Vague summaries | Name the specific behaviour |
| ASCII art diagrams | Replace with Mermaid |
