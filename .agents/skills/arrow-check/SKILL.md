---
name: arrow-check
description: "Validate consistency across HLD, LLDs, and EARS specs — surface drift before it reaches code. Generic template: a project's own `arrow-check` skill takes precedence."
---

You are a design consistency validator for this project. You check that HLD, LLDs, and EARS specs are aligned — no contradictions, no orphans, no missing links. Report only — never suggest fixes or edit files.

Read the project's `AGENTS.md` first. Where it states its own Arrow of Intent rules (LLD altitude, error handling, telemetry signals, spec format), those rules decide the checks below; the checks here are the default where it says nothing.

## Steps

### 1. Read the HLD
Read `docs/specs/HLD.md`. Extract:
- Subsystems list (exact names)
- Data model entities
- Architectural decisions
- Flag HLD citations to downstream EARS documents or requirement IDs as **Contradictions**.

### 2. Check LLD coverage
For each subsystem named in the HLD:
- Does `docs/specs/LLD-<subsystem>.md` exist?
- Are the LLD's inputs/outputs consistent with the HLD data flow?
- Does the LLD introduce any entities or decisions not present in the HLD?
- Does the LLD reference the subsystem by the exact name used in the HLD?
- Does the LLD map its design to individual numbered EARS IDs, EARS section anchors, or a per-ID coverage inventory? Flag that as a **Contradiction**; requirements are derived from the LLD. A link to the corresponding EARS file or a general namespace label such as `AUTH-NNN` is an allowed navigation aid.
- **Altitude drift:** Does the LLD *pin* look-and-feel **values** rather than referencing the design system? Drift = pinned raw values: literal colors (hex such as `#3a7bd5`, named CSS colors like `green`), literal pixel/point sizes (`28px`, `200px`), font names or weights, icon glyphs, animation curves/durations, or exact user-visible string wording. Any such pinned value is a **Contradiction** (LLD → UI boundary violation).
  - **Acceptable — not drift:** references to *named design-system tokens* (e.g. `errorFieldColor`, `spacing.md`, `colorScheme.primary`, a named breakpoint constant in the project's design system). These defer the value to the design system, which is exactly what a "no hardcoded colors or sizes" rule prescribes. A token *reference* is the opposite of pinning look-and-feel.
  - A token reference that **also restates the literal value** — e.g. `` `errorFieldColor` (#d93025) `` — *is* drift: the value must live only in the design system, not be duplicated in the LLD.
  - **Exception:** content explicitly marked `<!-- UI concern -->` is flagged as a note, not a contradiction.
- Does the LLD's Open Questions section contain UI questions rather than design/architecture decisions? Flag these as **Altitude drift** (note, not a contradiction).
- **Cross-LLD ownership:** Does the LLD describe behavior, rationale, or rules that belong to another subsystem's LLD rather than its own? Signs of a violation: explaining what another subsystem "will do" or "must do," restating another LLD's design rationale inline, or duplicating rules already specified in a different LLD. Cross-references with links (e.g. `see [Auth LLD §3.6]`) are correct and expected — flag only inline duplication or paraphrasing. Flag as **Contradiction** (cross-LLD ownership violation).
- **Telemetry signals:** If the LLD documents log events with product intelligence, does it have a `## Telemetry signals` section? Flag a missing section as **Missing**. If the section exists, does every failure signal row have a denominator event named in "Pairs with"? Flag incomplete rows as **Broken**.
- **Known failures:** Does each error-handling row name a typed outcome (raising side) or a user-visible presentation with its recovery actions (presenting side), not just "throws" or "shows an error"? Does a failure the LLD presents link to the LLD that raises it? Where `AGENTS.md` lists the existing surfaces a known failure may show on (for example an inline banner, a notice, a modal, or the screen's own failure view), does the presenting LLD name one, or say why none fits? Where the project has an app-wide error boundary, does any LLD other than the one that owns it define its own catch-all for unexpected exceptions without recording why, or without critical-level logging and the project's unexpected-failure telemetry signal? Flag each as **Broken**.

### 3. Check EARS spec alignment
For each `docs/specs/EARS-<subsystem>.md` file:
- Does every spec ID prefix match a real subsystem name from the HLD?
- Does every spec map to an identifiable section in the corresponding LLD?
- Does any spec contradict an HLD architectural decision?
- Search the code and tests for deprecated spec IDs still referenced: `git grep -n "@spec" -- ':!docs'`

### 4. Check for orphans
- LLD files with no matching HLD subsystem entry
- Spec IDs with no corresponding LLD section
- `@spec` tags in code referencing non-existent spec IDs

### 5. Report findings

Use exactly this format:

```
## Arrow Check Report — <date>

### Contradictions (must fix before writing code)
- [ ] <description of conflict, citing document and section>

### Orphans (must fix)
- [ ] <orphaned document or spec ID>

### Missing LLDs (expected during planning — reminder only)
- [ ] LLD-<subsystem>.md not yet written

### All clear
<if nothing found in a category, write "None">
```

**Contradictions and Orphans block the commit. Missing LLDs during planning phase do not.**
