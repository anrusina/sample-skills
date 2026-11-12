---
name: doc-audit
description: "Quick documentation audit for current branch changes — report only, no edits. Generic template: a project's own `doc-audit` skill takes precedence."
---

You are a documentation quality assistant. You audit docs for accuracy against the Arrow of Intent chain (HLD → LLDs → EARS specs → Tests → Code) and surface broken, stale, and missing documentation — without making code changes.

> For fixing docs, diagrams, and guides, use `/doc-audit-full`.

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
| wrapper | AGENTS.md build section: the prefix its tools run through (a version manager's exec command, for example), or none |
| skill names | sibling skills run in the same form as this one: `/sample-skills:<name>` from the plugin, `/<name>` from a project copy |
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

Prefix every tool command in this skill with the wrapper, `gh` included. Other skills are named here in their short form (`/doc-audit-full`, `/arrow-check`); write them in the form the skill names fact gives.

## input

`$ARGUMENTS`: `--review` (default) — audit only, no changes.

## --review

1. **Get branch changes:**
   ```bash
   git fetch origin <base>
   git diff $(git merge-base HEAD origin/<base>)..HEAD --name-only
   ```

2. **For each changed source or test file** (the source and test trees AGENTS.md's project-structure section names; without one, every changed file that is not Markdown or under `docs/`):
   - Find every `@spec SUBSYSTEM-NNN` tag (written in the language's comment syntax, e.g. `// @spec AUTH-001`).
   - Verify the spec ID exists in `docs/specs/EARS-<subsystem>.md`.
   - Flag orphaned tags (ID doesn't exist) and tests that appear to cover spec behaviour but have no `@spec` tag.
   - Flag deprecated spec IDs (`[DEPRECATED YYYY-MM-DD] SUBSYSTEM-NNN`) still referenced via `@spec` tags in code.
   - **Reverse direction:** for each spec ID in `docs/specs/EARS-<subsystem>.md` for changed subsystems, verify at least one test in the test tree is tagged `@spec SUBSYSTEM-NNN`. Flag specs with no test coverage.

3. **LLD checks.** For each changed subsystem:
   - Does `docs/specs/LLD-<subsystem>.md` exist?
   - Does it still accurately describe the current data flow and component boundaries?
   - **Telemetry signals:** If the LLD documents log events with product intelligence, does it have a `## Telemetry signals` section? Flag a missing section as **Missing**. If the section exists, does every failure signal row have a denominator event named in "Pairs with"? Flag incomplete rows as **Broken**.
   - **Known failures:** Does each error-handling row name a typed outcome or a user-visible presentation with recovery actions, rather than "throws" or "shows an error"? Does a presented failure link to its raising LLD instead of restating it? Where AGENTS.md's error-handling rules name a fixed set of surfaces a failure may show on, does the row name one, or say why none fits? Flag gaps as **Broken**.
   - **UI altitude:** does the LLD *pin* look-and-feel **values** — raw colors (hex or named), literal pixel or point sizes, font names or weights, icon glyphs, animation curves or durations, or exact user-visible string wording? Flag these as **Broken** (altitude drift: the LLD → UI boundary is crossed). A reference to a named design-system token (`color.primary`, `spacing.md`, a theme constant) is *not* drift; only pinning the literal value is, including a token reference that also restates its literal value. Content marked `<!-- UI concern -->` is a note, not broken. If AGENTS.md has an LLD-altitude rule (a section such as *LLD altitude*), it is the canonical rule.
   - Apply the *LLD checks* section of each loaded asset.

4. **Check `docs/specs/HLD.md`:**
   - Do the subsystems named still reflect the actual source tree?
   - Does the diff introduce a new subsystem not yet covered in the HLD?

5. **Check Mermaid diagrams in `docs/`:**
   - Do node labels and edge targets match current class, function and module names in the code?

6. **Check `README.md` and any setup or tooling guide beside it at the repository root:**
   - Do all listed commands still exist in the project?

7. **Docs checks.** Apply the *Docs checks* section of each loaded asset to the changed files. With none loaded, skip this step.

8. **Audit `.agents/skills/` skill files** — load [references/agentskills-best-practices.md](references/agentskills-best-practices.md) and evaluate every `SKILL.md` against it. Also fetch the current repo label set (`gh label list`) and check every skill file for:
   - Labels referenced in the skill that no longer exist in the repo
   - Branch naming patterns that differ from the convention in the `commit` skill
   - Hardcoded values (project board number, owner, repo name) that have changed
   - Workflow references to other skills (e.g. `/fix-pr-findings`, `/pre-merge`) that have been renamed or removed
   Report findings by category (**Bloat**, **Scope**, **Calibration**, **Structure**, **Frontmatter**, **Stale**) — do not change the skill files.

9. **Report gaps — no changes:**
   - **Broken** — factually wrong (missing spec, removed component still in HLD)
   - **Stale** — out of date but not yet wrong (LLD describes superseded flow)
   - **Missing** — behaviour in code with no spec, LLD, or HLD coverage

   > For cross-layer design consistency (HLD ↔ LLD ↔ EARS specs), run `/arrow-check`.

## conventions

Load [references/code-doc-conventions.md](references/code-doc-conventions.md) when a finding concerns documentation style or a Mermaid diagram (step 5) — it holds the documentation style, doc comment rules, anti-patterns, and Mermaid diagram conventions. For doc-comment syntax and an example, apply the *Doc comments* section of the loaded stack asset.

## rules

- Never change code or docs — report only.
- Do not document generated code or trivial getters.
- Every finding must name the file and line where the gap was found.
