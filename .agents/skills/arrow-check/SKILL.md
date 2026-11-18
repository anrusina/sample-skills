---
name: arrow-check
description: "Check that the HLD, LLDs and EARS specs agree with each other, and that every @spec tag in code cites a live spec: reports contradictions, orphans, broken rows and missing docs, and edits nothing. Use before writing code against the design docs, after changing an HLD, LLD or EARS file, or when /commit runs it as a gate. Not for writing or fixing the docs (/design-docs, /doc-audit-full) or auditing a branch's docs against its code (/doc-audit). Generic copy: if a project skill named `arrow-check` is also listed, use that one instead."
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/scripts/spec-ids.sh *)
---

You check that HLD, LLDs, and EARS specs are aligned — no contradictions, no orphans, no missing links. Report only: never edit files or suggest fixes; how intent changes is the developer's decision.

Read the project's `AGENTS.md` first. Where it states its own Arrow of Intent rules (LLD altitude, error handling, telemetry signals, spec format), those decide the checks below; these checks are the default where it says nothing. Find each section by what it holds, not its exact title.

## Steps

### 1. Read the HLD
Read `docs/specs/HLD.md`. Extract:
- Subsystems list (exact names)
- Data model entities
- Architectural decisions
- Flag HLD citations to downstream EARS documents or requirement IDs as **Contradictions**.

### 2. Check LLD coverage
For each subsystem named in the HLD:
- Does its LLD exist? It is the file `AGENTS.md`'s keyword → LLD table names for the subsystem, or else `docs/specs/LLD-<subsystem>.md` with the HLD name in lower case and spaces as dashes.
- Are the LLD's inputs/outputs consistent with the HLD data flow?
- Does the LLD introduce any entities or decisions not present in the HLD?
- Does the LLD reference the subsystem by the exact name used in the HLD?
- Does the LLD map its design to individual numbered EARS IDs, EARS section anchors, or a per-ID coverage inventory? Flag that as a **Contradiction**: requirements are derived from the LLD. A link to the EARS file or a namespace label such as `AUTH-NNN` is an allowed navigation aid.
- **Altitude drift:** a look-and-feel **value** pinned in the LLD is a **Contradiction** (LLD → UI boundary violation): literal colors (hex such as `#3a7bd5`, named CSS colors like `green`), literal pixel/point sizes (`28px`), font names or weights, icon glyphs, animation curves/durations, or exact user-visible wording.
  - **Not drift:** *named design-system tokens* (e.g. `errorFieldColor`, `spacing.md`, `colorScheme.primary`, a named breakpoint constant), a named text style, a design-system animation constant, a localization key, or a plain description ("the cancel label", "a check icon").
  - A token reference that **also restates the literal value** — e.g. `` `errorFieldColor` (#d93025) `` — *is* drift.
  - **Exception:** content marked `<!-- UI concern -->` is a note, not a contradiction.
- Does the LLD's Open Questions section contain UI questions rather than design/architecture decisions? Flag these as **Altitude drift** (note, not a contradiction).
- **Cross-LLD ownership:** flag as a **Contradiction** an LLD that describes behavior, rationale, or rules belonging to another subsystem's LLD: saying what another subsystem "will do" or "must do", restating another LLD's rationale, or duplicating its rules. Linked cross-references (e.g. `see [Auth LLD §3.6]`) are fine — flag only inline duplication or paraphrase.
- **Telemetry signals:** an LLD that documents log events with product intelligence but has no `## Telemetry signals` section is **Missing**; a failure signal row with no denominator event in "Pairs with" is **Broken**.
- **Known failures:** Does each error-handling row name a typed outcome (raising side) or a user-visible presentation with its recovery actions (presenting side), not just "throws" or "shows an error"? Does a failure the LLD presents link to the LLD that raises it? Where `AGENTS.md` lists the existing surfaces a known failure may show on (for example an inline banner, a notice, a modal, or the screen's own failure view), does the presenting LLD name one, or say why none fits? Where the project has an app-wide error boundary, does any LLD other than the one that owns it define its own catch-all for unexpected exceptions without recording why, or without critical-level logging and the project's unexpected-failure telemetry signal? Flag each as **Broken**.

### 3. Check EARS spec alignment
For each `docs/specs/EARS-<subsystem>.md` file:
- Does every spec ID prefix match a real subsystem name from the HLD?
- Does every spec map to an identifiable section in the corresponding LLD?
- Does any spec contradict an HLD architectural decision?
- Find code and tests that still cite a deprecated or undefined ID. The script reads both EARS forms (a `| ID |` table row and an `ID: When …` line) and skips `docs/`, `.agents/`, `.claude/` and Markdown:
  ```bash
  ${CLAUDE_SKILL_DIR}/scripts/spec-ids.sh orphans
  ```
  Pass the source and test folders `AGENTS.md`'s project-structure section names as arguments, when it names them. Each line is `file:line`, the ID, and `deprecated` or `undefined`.

### 4. Check for orphans
- LLD files with no matching HLD subsystem entry
- Spec IDs with no corresponding LLD section
- `@spec` tags citing an `undefined` or `deprecated` ID (step 3's script output)

### 5. Report findings

Use exactly this format, with a heading for every category (write "None" under an empty one):

```
## Arrow Check Report — <date>

### Contradictions (block the commit)
- [ ] <description of conflict, citing document and section>

### Orphans (block the commit)
- [ ] <orphaned document, spec ID, or `file:line` tag with its ID and why>

### Broken (block the commit)
- [ ] <incomplete telemetry row, error-handling row without a typed outcome or presentation, …>

### Missing (reminders: expected during planning)
- [ ] <LLD not yet written, Telemetry signals section not yet added>

### Notes (do not block)
- <altitude drift in Open Questions, content marked `<!-- UI concern -->`>
```
