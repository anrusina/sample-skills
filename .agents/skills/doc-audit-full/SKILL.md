---
name: doc-audit-full
description: "Bring the documentation back in line with the code: doc comments on public API, stale spec tags and LLD or HLD sections, READMEs and guides, Mermaid diagrams, and, only with --fix-skills, the skill files. Edits files across the repository, then commits and opens a PR, unless it runs inside a larger task. Use when the docs have drifted, after an audit, or when part of the codebase needs its docs written. Not for a report only (/doc-audit) or new design work (/design-docs). Generic copy: if a project skill named `doc-audit-full` is also listed, use that one instead."
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/../_shared/scripts/spec-ids.sh *)
---

You fix doc comments, update design docs, repair Mermaid diagrams, and keep the Arrow of Intent chain (HLD → LLDs → EARS specs → Tests → Code) accurate. Every run starts with the `/doc-audit` audit, then applies the requested fixes.

## Project facts

<!-- facts:begin -->
This is the generic copy: work out the facts below as
[../_shared/facts.md](../_shared/facts.md) says. A row marked *shared* takes
its rule from there.

| Fact | How to find it |
|---|---|
| `<base>` | *shared* |
| wrapper | *shared* |
| gates | *shared* |
| format fix | *shared* |
| skill names | *shared* |
| assets | *shared* |
<!-- facts:end -->

## input

| Flag | Meaning |
|---|---|
| `--review` | Audit only — report broken, stale, and missing. No changes |
| `--fix-comments` | Add or update doc comments on non-obvious public API |
| `--fix-docs` | Repair stale spec tags, update LLDs and HLD sections |
| `--fix-readme` | Update `README.md`, setup/tooling guides, and module guides |
| `--diagrams` | Update Mermaid diagrams to match current code |
| `--fix-skills` | Optimize `.agents/skills/` files against Agent Skills best practices |

No arguments → run every flag in order except `--fix-skills`, which runs only when named: in a project copy `/setup-skills` manages the skill files, and an edit conflicts with its next update.

## --review

Run `/doc-audit` (its `--review`) and report its findings; it loads its own assets.

## --fix-comments

1. Load [../_shared/code-doc-conventions.md](../_shared/code-doc-conventions.md); take the syntax from the *Code comments* section of the loaded stack asset.
2. Add or update doc comments only on public API where the contract is non-obvious:
   - Imperative summary sentence.
   - Document parameters and return values as short fragments.
   - No trailing periods on fragments. Mark identifiers the way the stack asset says.
   - Remove doc comments from trivial getters, test helpers, and generated code.
   - Apply the *Fix comments* section of each loaded asset.
3. Format the edited files: run the format fix, or the format gate when it writes in place. If the build section names no formatter, skip this step and say so in the summary.

## --fix-docs

### Repair path — upstream docs exist but drifted

1. For each orphaned `@spec` tag: update it only when the right ID is certain (the spec was renamed, and the EARS file or its history says to what). Otherwise list it as a gap: a guessed ID looks covered.
2. For each test covering spec behaviour but missing a `@spec` tag: add the correct spec ID.
3. For each deprecated spec still referenced in code: **do not auto-fix** — list as a gap for the developer to decide (un-deprecate, remap to a replacement spec, or remove the reference).
4. For each LLD with stale flow: update the affected sections only, leaving accurate prose alone.
5. Only when AGENTS.md defines telemetry signals for LLDs: for each LLD that documents log events with product intelligence but has no `## Telemetry signals` section, add one in the rate-pair format — columns Signal, Level, Emitted when, Product intelligence, Pairs with; the denominator (happy-path) event first, then each failure signal naming it in "Pairs with". If `/design-docs` is available, follow its LLD template's *Telemetry signals* section instead. Fill rows from the subsystem's log calls; mark intent-dependent fields `[NEEDS HUMAN INPUT]`.
6. For each HLD gap: add the missing subsystem entry or update the stale one. Describe what exists — do not invent architecture.
7. For each LLD that breaks [design-doc rule 2](../_shared/design-doc-rules.md) (a pinned look-and-feel value): replace the value with the design-system token it stands for or a plain description, or remove it when the sentence carries no behaviour without it. If no token exists, do not invent one: list it as a gap.
8. Apply the *Fix docs* section of each loaded asset.

### Bootstrap path — code exists with no upstream docs

When a subsystem has code but no HLD entry, LLD, or EARS specs, generate draft scaffolding:

1. **Draft HLD subsystem entry** — fill in Responsibility, Inputs, and Outputs from code. Mark any section that requires design intent as `[NEEDS HUMAN INPUT: <what is missing>]`. Do not invent architectural decisions or scope boundaries.

2. **Draft LLD** — fill in Purpose, Inputs/Outputs, Component design, Data structures, and Telemetry signals from code. Mark Error handling rationale, telemetry signal intent, and Open questions as `[NEEDS HUMAN INPUT]`. Create the file as `docs/specs/LLD-<subsystem>.md` with this banner at the top:
   ```
   > ⚠️ DRAFT — generated from code, verify intent before treating as authoritative.
   ```

3. **Draft EARS specs** — derive from observable behaviour in code:
   - Condition specific and testable.
   - Action observable — never "handle", "manage", or "process".
   - Mark each generated spec `[DRAFT]` until a human confirms its intent.

4. **Output a gaps list** at the end of the run — one item per `[NEEDS HUMAN INPUT]` section, phrased as issue titles suitable for `/issue`:
   ```
   Gaps requiring human input:
   - [ ] Define architectural decisions for <subsystem> LLD
   - [ ] Confirm error handling rationale for <subsystem>
   - [ ] Verify intent of [DRAFT] spec SUBSYSTEM-NNN (derived from code, not from design)
   ```

> After running `--fix-docs`, run `/arrow-check` to confirm no cross-layer contradictions were introduced.

## --fix-readme

1. Update `README.md`:
   - Add new commands or scripts; remove references to deleted ones.
   - Verify Quick Start commands still work.
2. Update any setup or tooling guide beside `README.md` whose setup steps changed.
3. For any new subsystem in the source tree that lacks a module-level README, create one with:
   - **Purpose** — one paragraph: what this module does and where it sits in the Arrow of Intent chain.
   - **Data flow** — Mermaid `sequenceDiagram` or `flowchart LR`.
   - **Key files** — annotated directory tree in a `text` block.

## --diagrams

1. Find all Mermaid diagrams in `docs/` and `README.md`.
2. Cross-check node and edge labels against current class, function and module names in the code.
3. Update stale labels, add missing nodes, remove deleted ones — maintain the existing abstraction level.
4. Use `flowchart LR` for data flows; `flowchart TD` for hierarchies; `sequenceDiagram` for call sequences.

## --fix-skills

Load [../_shared/agentskills-best-practices.md](../_shared/agentskills-best-practices.md) before starting.

For each `SKILL.md` in `.agents/skills/`, leaving every facts block (`<!-- facts:begin -->` … `<!-- facts:end -->`) untouched, since `/setup-skills` writes it:

1. **Bloat** — cut any instruction the agent would not get wrong without it (general concepts, standard library behaviour).

2. **Progressive disclosure** — if the file exceeds 500 lines or holds large inline reference blocks: extract them to `references/<topic>.md` or `assets/<template>.md` with a conditional load instruction (`"load references/X.md if [condition]"`), never a bare "see references/".

3. **Calibration** — where 3+ equivalent options have no clear default: pick the best default and relegate alternatives to a one-line note. Replace declaration-style output specs with a reusable procedure where the task class generalises.

4. **Frontmatter** — add missing required fields. Check `disable-model-invocation` against the project's invocation-gating table (in `AGENTS.md`, then `docs/dev/skills.md`) and report any skill whose flag differs; with no such table, skip this check and say so in the summary. Never add or remove the flag yourself: opening a skill to model invocation is a recorded decision, not a style fix. Add or complete `allowed-tools` with specific `Bash(pattern *)` entries. Flag model mismatches (see the calibration table in the reference).

5. **Structure gaps** — add a `## gotchas` section when domain-specific traps exist but aren't documented. Convert prose output format descriptions to a template stored in `assets/`.

6. **Stale references** — update renamed skill references, wrong label names, and changed hardcoded values.

After all edits, print a summary: one bullet per skill file changed, with the category of fix and why.

## conventions

Load [../_shared/code-doc-conventions.md](../_shared/code-doc-conventions.md) for `--fix-comments` and `--diagrams` — documentation style, doc comment rules, anti-patterns, and Mermaid conventions.

## rules

- When the edits are done, print the summary, then run `/commit-and-pr`, or `/commit` when the branch already has an open PR: the developer reviews the change in the PR. When this run is a step of a larger task (a coordinator's brief, another skill), leave committing to that task.
- Do not document generated code: the next generation run overwrites it.
