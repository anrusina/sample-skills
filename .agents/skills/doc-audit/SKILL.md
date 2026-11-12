---
name: doc-audit
description: "Quick documentation audit for current branch changes — report only, no edits. Generic template: a project's own `doc-audit` skill takes precedence."
model: claude-haiku-4-5-20251001
---

You are a documentation quality assistant. You audit docs for accuracy against the Arrow of Intent chain (HLD → LLDs → EARS specs → Tests → Code) and surface broken, stale, and missing documentation — without making code changes.

> For fixing docs, diagrams, and guides, use `/doc-audit-full`.

**Tool wrapper.** If `AGENTS.md` *Build and test commands* says tools run through a wrapper (for example a version manager's exec command), prefix every tool command below with it, `gh` included.

## input

`$ARGUMENTS`: `--review` (default) — audit only, no changes.

## --review

1. **Get branch changes:**
   ```bash
   BASE=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name')   # fallback: git symbolic-ref --short refs/remotes/origin/HEAD
   git diff $(git merge-base HEAD origin/$BASE)..HEAD --name-only
   ```

2. **For each changed source or test file** (the source and test trees `AGENTS.md`'s project structure names; without one, every changed file that is not Markdown or under `docs/`):
   - Find every `@spec SUBSYSTEM-NNN` tag (written in the language's comment syntax, e.g. `// @spec AUTH-001`).
   - Verify the spec ID exists in `docs/specs/EARS-<subsystem>.md`.
   - Flag orphaned tags (ID doesn't exist) and tests that appear to cover spec behaviour but have no `@spec` tag.
   - Flag deprecated spec IDs (`[DEPRECATED YYYY-MM-DD] SUBSYSTEM-NNN`) still referenced via `@spec` tags in code.
   - **Reverse direction:** for each spec ID in `docs/specs/EARS-<subsystem>.md` for changed subsystems, verify at least one test in the test tree is tagged `@spec SUBSYSTEM-NNN`. Flag specs with no test coverage.

3. **For each changed subsystem, check the LLD:**
   - Does `docs/specs/LLD-<subsystem>.md` exist?
   - Does it still accurately describe the current data flow and component boundaries?
   - **UI altitude:** Does the LLD *pin* look-and-feel **values** — raw colors (hex/named), literal pixel/point sizes, font names or weights, icon glyphs, animation curves/durations, or exact user-visible string wording? Flag these as **Broken** (altitude drift — LLD → UI boundary violation). References to named design-system tokens (`color.primary`, `spacing.md`, a theme constant) are *not* drift — only pinning the literal value is, including a token reference that also restates its literal value. Content explicitly marked `<!-- UI concern -->` is a note, not broken. If `AGENTS.md` has an *LLD altitude* section, it is the canonical rule.
   - **Telemetry signals:** If the LLD documents log events with product intelligence, does it have a `## Telemetry signals` section? Flag a missing section as **Missing**. If the section exists, does every failure signal row have a denominator event named in "Pairs with"? Flag incomplete rows as **Broken**.
   - **Known failures:** Does each error-handling row name a typed outcome or a user-visible presentation with recovery actions, rather than "throws" or "shows an error"? Does a presented failure link to its raising LLD instead of restating it? Where `AGENTS.md`'s error-handling rules name a fixed set of surfaces a failure may show on, does the row name one, or say why none fits? Where `AGENTS.md` names a component catalog and requires failure states in it, does the UI LLD's catalog list include the state? Flag gaps as **Broken**.

4. **Check `docs/specs/HLD.md`:**
   - Do the subsystems named still reflect the actual source tree?
   - Does the diff introduce a new subsystem not yet covered in the HLD?

5. **Check Mermaid diagrams in `docs/`:**
   - Do node labels and edge targets match current class, function and module names in the code?

6. **Check `README.md` and any setup or tooling guide beside it at the repository root:**
   - Do all listed commands still exist in the project?

7. **Audit `.agents/skills/` skill files** — load [references/agentskills-best-practices.md](references/agentskills-best-practices.md) and evaluate every `SKILL.md` against it. Also fetch the current repo label set (`gh label list`) and check every skill file for:
   - Labels referenced in the skill that no longer exist in the repo
   - Branch naming patterns that differ from the convention in the `commit` skill
   - Hardcoded values (project board number, owner, repo name) that have changed
   - Workflow references to other skills (e.g. `/fix-pr-findings`, `/pre-merge`) that have been renamed or removed
   Report findings by category (**Bloat**, **Scope**, **Calibration**, **Structure**, **Frontmatter**, **Stale**) — do not change the skill files.

8. **Report gaps — no changes:**
   - **Broken** — factually wrong (missing spec, removed component still in HLD)
   - **Stale** — out of date but not yet wrong (LLD describes superseded flow)
   - **Missing** — behaviour in code with no spec, LLD, or HLD coverage

   > For cross-layer design consistency (HLD ↔ LLD ↔ EARS specs), run `/arrow-check`.

## conventions

Load [conventions/code-doc-conventions.md](conventions/code-doc-conventions.md) when a finding concerns documentation style or a Mermaid diagram (step 5) — it holds the documentation style, doc comment examples, and Mermaid diagram conventions.

## rules

- Never change code or docs — report only.
- Do not document generated code or trivial getters.
- Every finding must name the file and line where the gap was found.
