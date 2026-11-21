---
name: arrow-check
description: "Check that the HLD, LLDs and EARS specs agree with each other, and that every @spec tag in code cites a live spec: reports contradictions, orphans, broken rows and missing docs, and edits nothing. Use before writing code against the design docs, after changing an HLD, LLD or EARS file, or when /commit runs it as a gate. Not for writing or fixing the docs (/design-docs, /doc-audit-full) or auditing a branch's docs against its code (/doc-audit). Generic copy: if a project skill named `arrow-check` is also listed, use that one instead."
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/../_shared/scripts/spec-ids.sh *)
---

You check that HLD, LLDs, and EARS specs are aligned — no contradictions, no orphans, no missing links. Report only: never edit files or suggest fixes; how intent changes is the developer's decision.

Read the project's `AGENTS.md` first. Where it states its own Arrow of Intent rules (LLD altitude, error handling, telemetry signals, spec format), those decide the checks below; these checks are the default where it says nothing. Find each section by what it holds, not its exact title.

## Steps

### 1. Read the HLD
Read `docs/specs/HLD.md`. Extract:
- Subsystems list (exact names)
- Data model entities
- Architectural decisions
- Flag HLD citations to EARS files or requirement IDs (design-doc rule 1) as **Contradictions**.

### 2. Check LLD coverage
For each subsystem named in the HLD:
- Does its LLD exist? It is the file `AGENTS.md`'s keyword → LLD table names for the subsystem, or else `docs/specs/LLD-<subsystem>.md` with the HLD name in lower case and spaces as dashes.
- Are the LLD's inputs/outputs consistent with the HLD data flow?
- Does the LLD introduce any entities or decisions not present in the HLD?
- Does the LLD reference the subsystem by the exact name used in the HLD?
- Check the LLD against the [design-doc rules](../_shared/design-doc-rules.md), and file each breach:
  - rules 1 (an EARS-ID mapping), 2 (a pinned look-and-feel value) and 3 (cross-LLD ownership): **Contradiction**;
  - a UI question in Open Questions: **Altitude drift** (a note, not a contradiction);
  - rule 4: no `## Telemetry signals` section is **Missing**; a failure signal with no denominator is **Broken**;
  - rule 5 (known failures): **Broken**.

### 3. Check EARS spec alignment
For each `docs/specs/EARS-<subsystem>.md` file:
- Does every spec ID prefix match a real subsystem name from the HLD?
- Does every spec map to an identifiable section in the corresponding LLD?
- Does any spec contradict an HLD architectural decision?
- Find code and tests that still cite a deprecated or undefined ID. The script reads both EARS forms (a `| ID |` table row and an `ID: When …` line) and skips `docs/`, `.agents/`, `.claude/` and Markdown:
  ```bash
  ${CLAUDE_SKILL_DIR}/../_shared/scripts/spec-ids.sh orphans
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
