# LLD altitude rules — Flutter / Material Design

## What counts as drift

LLDs must not pin look-and-feel values. Drift = raw literals that belong in the design system:

| Drift (flag as Contradiction) | Acceptable (not drift) |
| --- | --- |
| Hex colour `#59ee73` | Named token `colorScheme.primary` |
| Named CSS colour `green` | Named token `highlightCellColor` |
| Literal size `28.0`, `200px` | Named spacing constant `AppSpacing.md` |
| Font name `Roboto`, weight `700` | `textTheme.titleMedium` |
| Icon glyph `Icons.check` | Generic "check icon" description |
| Animation duration `300ms` | Design-system animation constant |
| Exact string wording `"Cancel"` | `l10n.cancelLabel` or generic "cancel label" |

A token *reference* that **also restates the literal value** — e.g. `` `highlightCellColor` (#59ee73) `` — is still drift: the value must live only in the design system, not be duplicated in the LLD.

## Acceptable exceptions

Content explicitly marked `<!-- UI concern — see wireframe -->` is flagged as a note, not a contradiction.

## Enforcement

The `arrow-check` skill flags pinned values as **Contradictions** (blocking). The `doc-audit` skill flags them as **Broken** (LLD → UI boundary violation).
