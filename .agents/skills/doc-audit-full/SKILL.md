---
name: doc-audit-full
description: "Bring the documentation back in line with the code: doc comments on public API, stale spec tags and LLD or HLD sections, READMEs and guides, Mermaid diagrams, and, only with --fix-skills, the skill files. Edits files across the repository but never commits. Use when the docs have drifted, after an audit, or when part of the codebase needs its docs written. Not for a report only (/doc-audit) or new design work (/design-docs). Generic copy: if a project skill named `doc-audit-full` is also listed, use that one instead."
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/scripts/spec-ids.sh *)
---

You are a documentation quality assistant. You fix doc comments, update design docs, repair Mermaid diagrams, and keep the Arrow of Intent chain (HLD → LLDs → EARS specs → Tests → Code) accurate — without the developer having to track drift manually.

> For audit only (no changes), use `/doc-audit`.

Runs the audit from `/doc-audit` first, then applies the requested fixes.

## Project facts

<!-- facts:begin -->
This is the generic copy: no project facts are written into it. Work out each
fact below once, at the start of the run, then write its value literally into
every command that needs it. Each Bash call starts a fresh shell, so a variable
set in one call is empty in the next; never carry a value across calls in a
shell variable.

| Fact | How to find it |
|---|---|
| `<base>` | `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`; if that fails, `git symbolic-ref --short refs/remotes/origin/HEAD \| sed 's\|^origin/\|\|'` |
| wrapper | AGENTS.md build section: the prefix the toolchain runs through (a version manager's exec command, for example), or none. Run the gates, and each tool the wrapper provides (the tools its config file lists), through it; pass it to this skill's scripts as `--wrap '<wrapper>'` (leave `--wrap` out when it is none); run every other command bare, so it matches `allowed-tools` |
| gates | AGENTS.md build section: the format, lint/analyze and test commands, in order, or the one command that runs them all |
| format fix | AGENTS.md build section: the write-mode formatter, if the format gate only checks |
| skill names | `/<name>` when the primary checkout (`dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`) holds the skill in `.agents/skills/<name>/` or `.claude/skills/<name>/`; otherwise the form this skill was installed in: `/sample-skills:<name>` from the plugin, `sample-skills-<name>` from a Codex install. Other skills are named in this file in their short form (`/<name>`); write each in the form this rule gives |
| assets | the stack and field assets that apply: see *Assets* below |

**AGENTS.md sections by role.** Projects name sections differently. The build
section is the one that lists the build, format, lint and test commands,
whatever it is called (*Build and test commands*, *Build commands*, *Tools*,
*Commands*). Match every section this skill reads the same way: by what it
holds, not by its exact title. When a required fact is missing, ask the
developer once, use the answer, and tell them which AGENTS.md section to
record it in.

**Assets.** This skill keeps stack and field assets under `assets/stack/` and
`assets/field/`; `assets/index.md` says when each applies. At the start of the
run, load every asset whose condition holds, and apply each where a step names
its section. With none loaded, the steps' generic text applies.
<!-- facts:end -->

## input

| Flag | Meaning |
|---|---|
| `--review` | Audit only — report broken, stale, and missing. No changes |
| `--fix-comments` | Add or update doc comments on non-obvious public API |
| `--fix-docs` | Repair stale spec tags, update LLDs and HLD sections |
| `--fix-readme` | Update `README.md`, setup/tooling guides, and module guides |
| `--diagrams` | Update Mermaid diagrams to match current code |
| `--fix-skills` | Optimize `.agents/skills/` files against Agent Skills best practices (only when named) |

No arguments → run every flag in order except `--fix-skills`, which runs only when named: it rewrites skill files, and in a project copy `/setup-skills` manages those (an edit there conflicts with the next update), so it is never a side effect of a documentation pass.

## --review

Same as `/doc-audit`: follow its `--review` steps, with its assets (its `SKILL.md` sits beside this skill's folder, at `${CLAUDE_SKILL_DIR}/../doc-audit/SKILL.md`, or `sample-skills-doc-audit` in a Codex install). Always run first in every invocation.

## --fix-comments

1. Load [references/code-doc-conventions.md](references/code-doc-conventions.md) for doc comment style and conventions, and apply the *Doc comments* section of the loaded stack asset for the syntax.
2. Add or update doc comments only on public API where the contract is non-obvious, in the language's doc-comment syntax:
   - Imperative summary sentence.
   - Document parameters and return values as short fragments.
   - No trailing periods on fragments. Mark identifiers the way the stack asset says.
   - Remove doc comments from trivial getters, test helpers, and generated code.
   - Apply the *Fix comments* section of each loaded asset.
3. Format the edited files: run the format fix, or the format gate when it writes in place. If the build section names no formatter, skip this step and say so in the summary.

## --fix-docs

### Repair path — upstream docs exist but drifted

1. For each orphaned `@spec` tag: update it only when the right ID is certain (the spec was renamed, and the EARS file or its history says to what). Otherwise list it as a gap; a guessed ID is worse than an orphan, because it looks covered.
2. For each test covering spec behaviour but missing a `@spec` tag: add the correct spec ID.
3. For each deprecated spec still referenced in code: **do not auto-fix** — list as a gap requiring human decision (un-deprecate, remap to a replacement spec, or remove the reference).
4. For each LLD with stale flow: update the affected sections only. Do not rewrite prose that is still accurate.
5. Only when AGENTS.md defines telemetry signals for LLDs: for each LLD that documents log events with product intelligence but has no `## Telemetry signals` section: draft and add the section in the rate-pair format — a table with columns Signal, Level, Emitted when, Product intelligence, Pairs with; the denominator event (the happy-path event confirming normal completion) first, then each failure signal naming that denominator in "Pairs with". If the `/design-docs` skill is available, follow its LLD template's *Telemetry signals* section instead. Populate signal rows from observable log calls in the subsystem code. Mark intent-dependent fields `[NEEDS HUMAN INPUT]`.
6. For each HLD gap: add the missing subsystem entry or update the stale one. Describe what exists — do not invent architecture.
7. For each LLD that pins a look-and-feel value (a raw color, a literal size, a font, an icon glyph, an animation value or exact string wording): replace the value with the design-system token it stands for, or remove it when the sentence carries no behaviour without it. If no token exists for the value, do not invent one: list it as a gap for the developer. AGENTS.md's LLD-altitude rule, if it has one, is the canonical rule.
8. Apply the *Fix docs* section of each loaded asset.

### Bootstrap path — code exists with no upstream docs

When a subsystem has code but no HLD entry, LLD, or EARS specs, generate draft scaffolding as a starting point:

1. **Draft HLD subsystem entry** — fill in Responsibility, Inputs, and Outputs from code. Mark any section that requires design intent as `[NEEDS HUMAN INPUT: <what is missing>]`. Do not invent architectural decisions or scope boundaries.

2. **Draft LLD** — fill in Purpose, Inputs/Outputs, Component design, Data structures, and Telemetry signals from code. Mark Error handling rationale, telemetry signal intent, and Open questions as `[NEEDS HUMAN INPUT]`. Create the file as `docs/specs/LLD-<subsystem>.md` with this banner at the top:
   ```
   > ⚠️ DRAFT — generated from code, verify intent before treating as authoritative.
   ```

3. **Draft EARS specs** — derive from observable behaviour in code. Apply quality rules:
   - Condition must be specific and testable.
   - Action must be observable — never use "handle", "manage", or "process".
   - Mark each generated spec `[DRAFT]` until a human confirms the intent matches design decisions.

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
2. Update any setup or tooling guide beside `README.md` if any setup steps have changed.
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

Load [references/agentskills-best-practices.md](references/agentskills-best-practices.md) before starting.

For each `SKILL.md` in `.agents/skills/`, leaving every facts block (`<!-- facts:begin -->` … `<!-- facts:end -->`) untouched, since `/setup-skills` writes it:

1. **Bloat** — remove prose that explains things the agent already knows from training (general concepts, standard library behaviour). Cut any instruction where "would the agent get this wrong without it?" is no.

2. **Progressive disclosure** — if the file exceeds 500 lines or contains large inline reference blocks: extract them to `references/<topic>.md` or `assets/<template>.md` with an explicit conditional load instruction (`"load references/X.md if [condition]"`). Do not use a generic "see references/" pointer without a condition.

3. **Calibration** — if instructions present 3+ equivalent options without a clear default: pick the best default and relegate alternatives to a one-line note. Replace declaration-style output specs with a reusable procedural approach where the task class generalises.

4. **Frontmatter** — add missing required fields. Check `disable-model-invocation` against the project's invocation-gating table, if it records one: look in `AGENTS.md`, then `docs/dev/skills.md`, for a table listing which skills are gated, and report any skill whose flag differs from it. If neither file has such a table, skip this check and say so in the summary. Never add or remove the flag yourself, since opening a skill to model invocation is a recorded decision, not a style fix. Add or complete `allowed-tools` with specific `Bash(pattern *)` entries. Flag model mismatches (see calibration table in the reference).

5. **Structure gaps** — add a `## gotchas` section when domain-specific traps exist but aren't documented. Convert prose output format descriptions to a template stored in `assets/`.

6. **Stale references** — update renamed skill references, wrong label names, and changed hardcoded values.

After all edits, print a summary: one bullet per skill file changed, listing what category of fix was applied and why.

> Do not commit — let the developer review the diff first.

## conventions

Load [references/code-doc-conventions.md](references/code-doc-conventions.md) for `--fix-comments` and `--diagrams` — it holds the documentation style, doc comment rules, anti-patterns, and Mermaid diagram conventions. The doc-comment syntax and an example come from the *Doc comments* section of the loaded stack asset.

## rules

- Do not commit: print a summary and let the developer review the diff first.
- Do not document generated code: the next generation run overwrites it.
