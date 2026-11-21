---
name: doc-audit
description: "Audit the current branch's documentation against its changes, report only: orphaned or deprecated @spec tags, specs with no tests, LLDs, HLD and Mermaid diagrams that no longer match the code, stale READMEs, and the skill files it changed. Edits nothing. Use before opening or merging a PR that touches code or docs, or when asked whether the docs are still accurate. Not for fixing what it finds (/doc-audit-full) or checking the design docs against each other (/arrow-check). Generic copy: if a project skill named `doc-audit` is also listed, use that one instead."
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/../_shared/scripts/spec-ids.sh *)
---

You audit docs for accuracy against the Arrow of Intent chain (HLD → LLDs → EARS specs → Tests → Code) and report broken, stale and missing documentation.

## Project facts

<!-- facts:begin -->
This is the generic copy: work out the facts below as
[../_shared/facts.md](../_shared/facts.md) says. A row marked *shared* takes
its rule from there.

| Fact | How to find it |
|---|---|
| `<base>` | *shared* |
| wrapper | *shared* |
| skill names | *shared* |
| assets | *shared* |
<!-- facts:end -->

## input

`$ARGUMENTS`: `--review` (default).

## --review

1. **Get branch changes:**
   ```bash
   git fetch origin <base>
   git diff $(git merge-base HEAD origin/<base>)..HEAD --name-only
   ```

2. **For each changed source or test file** (the source and test trees AGENTS.md's project-structure section names; without one, every changed file that is not Markdown or under `docs/`):
   - Find the tags whose ID is undefined or deprecated, reading both EARS forms (table row and `ID: When …` line):
     ```bash
     ${CLAUDE_SKILL_DIR}/../_shared/scripts/spec-ids.sh --wrap '<wrapper>' orphans <the changed source and test files>
     ```
     Each line is `file:line`, the ID, and `undefined` (an orphaned tag) or `deprecated` (a deprecated spec still cited).
   - Flag tests that appear to cover spec behaviour but have no `@spec` tag.
   - **Reverse direction:** flag each spec ID in `docs/specs/EARS-<subsystem>.md` for a changed subsystem that no test in the test tree tags `@spec SUBSYSTEM-NNN`.

3. **LLD checks.** For each changed subsystem:
   - Does `docs/specs/LLD-<subsystem>.md` exist?
   - Does it still accurately describe the current data flow and component boundaries?
   - Check it against the [design-doc rules](../_shared/design-doc-rules.md): rules 1, 2 and 3 always; rule 4 only when AGENTS.md defines telemetry signals for LLDs, and rule 5 only when it has error-handling rules for LLDs. A breach is **Broken**, except a missing `## Telemetry signals` section, which is **Missing**, and a UI question in Open Questions, which is a note.
   - Apply the *LLD checks* section of each loaded asset.

4. **Check `docs/specs/HLD.md`:**
   - Do the subsystems named still reflect the actual source tree?
   - Does the diff introduce a new subsystem not yet covered in the HLD?

5. **Check Mermaid diagrams in `docs/`:**
   - Do node labels and edge targets match current class, function and module names in the code?

6. **Check `README.md` and any setup or tooling guide beside it at the repository root:**
   - Do all listed commands still exist in the project?

7. **Docs checks.** Apply the *Docs checks* section of each loaded asset to the changed files. With none loaded, skip this step.

8. **Audit the skill files this branch changed** (under `.agents/skills/`; skip this step when it changed none) — load [../_shared/agentskills-best-practices.md](../_shared/agentskills-best-practices.md) and evaluate each changed `SKILL.md` against it, its stale-reference checks included. Report each as **Broken** or **Stale** in step 9, saying which category it is (bloat, scope, calibration, structure, frontmatter, stale).

9. **Report gaps:**
   - **Broken** — factually wrong (missing spec, removed component still in HLD)
   - **Stale** — out of date but not yet wrong (LLD describes superseded flow)
   - **Missing** — behaviour in code with no spec, LLD, or HLD coverage

   > For cross-layer design consistency (HLD ↔ LLD ↔ EARS specs), run `/arrow-check`.

## conventions

Load [../_shared/code-doc-conventions.md](../_shared/code-doc-conventions.md) when a finding concerns documentation style or a Mermaid diagram (step 5) — it holds the documentation style, doc comment rules, anti-patterns, and Mermaid diagram conventions. For doc-comment syntax and an example, apply the *Code comments* section of the loaded stack asset.

## rules

- Report only: never change code or docs. The developer decides what to fix, with `/doc-audit-full` or by hand.
- Every finding names the file and line where the gap was found, so it can be acted on without searching.
