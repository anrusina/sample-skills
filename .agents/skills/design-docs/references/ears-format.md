# EARS spec format (`docs/specs/EARS-<subsystem>.md`)

**EARS** = Easy Approach to Requirements Syntax. A structured sentence format that makes requirements unambiguous and directly testable.

## Templates

| Type | Pattern | Use when |
|---|---|---|
| Event-driven | `When [trigger], the system shall [action].` | A specific event causes a behaviour |
| State-driven | `While [state], the system shall [action].` | Ongoing behaviour during a persistent state |
| Conditional | `If [condition], the system shall [action].` | Behaviour that depends on an optional feature or one-time condition |
| Unwanted behaviour | `If [unwanted condition], the system shall [response].` | Error handling, failure modes |
| Ubiquitous | `The system shall [action].` | Invariant behaviour with no trigger |

Use **event-driven** as the default form, unless the project's `AGENTS.md` says otherwise. Switch to another only when event-driven produces an awkward fit.

## Spec ID format

Each spec is one row in an `| ID | Spec |` table:

```
| ID | Spec |
| --- | --- |
| SUBSYSTEM-NNN | When [condition], the system shall [action]. |
```

**Rules:**
- Every spec maps to exactly one LLD section
- Every spec has at least one test tagged `// @spec SUBSYSTEM-NNN` (in the test language's comment syntax)
- Spec IDs are append-only — never renumber
- Mark superseded specs in the ID cell: `[DEPRECATED YYYY-MM-DD] SUBSYSTEM-NNN`
- Condition must be specific and testable
- Action must be observable — never use "handle", "manage", or "process"

**Good:**
```
| ID | Spec |
| --- | --- |
| AUTH-001 | When a user submits invalid credentials, the system shall show an error and clear the password field. |
| CART-002 | When a user changes an item's quantity, the system shall recalculate the line total and the cart subtotal. |
```

**Bad (too vague):**
```
| ID | Spec |
| --- | --- |
| AUTH-001 | When the user interacts with the sign-in form, the system shall handle it appropriately. |
```

## Telemetry signal check

After writing behavioural specs, apply this check to every spec that mandates a log call:

1. Does the log event carry product intelligence beyond noise?
2. If yes — does a telemetry signal entry exist in the backing LLD's `## Telemetry signals` section? Add one if not.
3. Ensure the denominator event for this subsystem is documented before adding failure signals.
