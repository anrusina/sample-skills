# EARS spec format (`docs/specs/<subsystem>-specs.md`)

**EARS** = Easy Approach to Requirements Syntax. A structured sentence format that makes requirements unambiguous and directly testable.

## Templates

| Type | Pattern | Use when |
| --- | --- | --- |
| Event-driven | `When [trigger], the system shall [action].` | A specific event causes a behaviour |
| State-driven | `While [state], the system shall [action].` | Ongoing behaviour during a persistent state |
| Conditional | `If [condition], the system shall [action].` | Behaviour that depends on an optional feature or one-time condition |
| Unwanted behaviour | `If [unwanted condition], the system shall [response].` | Error handling, failure modes |
| Ubiquitous | `The system shall [action].` | Invariant behaviour with no trigger |

Use **event-driven** as the default form. Switch to another only when event-driven produces an awkward fit.

## Spec ID format

Each spec is one line with a unique ID:

```text
SUBSYSTEM-NNN: When [condition], the system shall [action].
```

**Rules:**

- Every spec maps to exactly one LLD section
- Every spec has at least one test tagged `// @spec SUBSYSTEM-NNN`
- Spec IDs are append-only — never renumber
- Mark superseded specs: `[DEPRECATED YYYY-MM-DD] SUBSYSTEM-NNN: ...`
- Condition must be specific and testable
- Action must be observable — never use "handle", "manage", or "process"

**Good:**

```text
GRID-001: When a user confirms a selection, the system shall mark all selected cells as done and update the legend count for the affected symbol.
LEGEND-001: When a user taps a symbol in the legend, the system shall apply the highlighted state to all grid cells matching that symbol.
```

**Bad (too vague):**

```text
GRID-001: When the user interacts with the grid, the system shall handle it appropriately.
```
