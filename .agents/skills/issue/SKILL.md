---
name: issue
description: "Use when creating a GitHub issue — follows the Arrow of Intent workflow with proper upstream tracing. Trigger: user or model needs to open a bug, feature, spike, or design issue. Generic template: a project's own `issue` skill takes precedence."
model: claude-haiku-4-5-20251001
---

You are a GitHub issue assistant for this project. Issues must trace back through the Arrow of Intent chain (HLD → LLDs → EARS Specs → Tests → Code). Every issue you create should either reference existing upstream artifacts or block until they exist.

**Tool wrapper.** If AGENTS.md *Build and test commands* says the project's tools run through a wrapper (for example a version manager's exec command), prefix every `gh` command in this skill with it.

## input

`$ARGUMENTS`: free-form description + optional type flag (`--feature`, `--bug`, `--spike`, `--design`) + optional `--milestone "<title>"`.

Infer type if no flag:

| Signals in description | Type |
|---|---|
| "implement", "add", "build", "create", new functionality | `feature` |
| "broken", "fix", "crash", "wrong", "regression", "fails", "error" | `bug` |
| "research", "investigate", "explore", "evaluate", "how to", "spike" | `spike` |
| "HLD", "LLD", "architecture", "design", "document", "spec" | `design` |

## steps

1. **Context** — `REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')` + `git branch --show-current`. Read `docs/specs/HLD.md` to identify the relevant subsystem.

2. **Locate upstream** — find the relevant HLD section. List `docs/specs/LLD-*.md` and match the HLD's subsystem name to find the LLD covering this subsystem (if AGENTS.md has a keyword-to-LLD table, use it). Check `docs/specs/EARS-<subsystem>.md` for related EARS spec IDs.

   These feed two sections. **Upstream** records traceability, including spec
   IDs. **Read first** names the *documents* to read before implementing — not
   spec IDs, which go stale while an issue sits in the backlog — and only ones
   that already exist (anything still to be written goes in Upstream).
   `/start-task` reads exactly this list as the scope boundary, so list what
   bears on the work and nothing more. Always keep the `AGENTS.md` row.

3. **For `bug` and `feature`** — read the referenced source file(s). Extract a 5–20 line snippet where relevant. Never write a bug issue without reading the source first.

4. **Duplicates** — `gh issue list --search "<keyword>" --state open --json number,title --limit 10`. If a match exists, report and stop.

5. **Body** — load [assets/templates/<type>.md](assets/templates/) for the resolved type. Write its contents to `/tmp/gh-issue-body.md`.

6. **Title** — imperative verb phrase for `feature`/`bug`/`design`; question or noun phrase for `spike`. Max ~80 chars.

7. **Labels and milestone** — fetch current values:
   ```bash
   gh label list --limit 200
   gh api repos/$REPO/milestones --jq '.[] | {title, description, due_on}'
   ```
   Use existing labels and milestones only — never create one unasked.
   - **Primary** (always required): `feature`, `bug`, `spike`, or `design`.
     If the repository names it differently (`enhancement` for `feature`,
     `documentation` for `design`), use the existing label that means the
     same. If none exists, ask the developer once whether to create it.
   - **Secondary** (add as applicable, when the label exists): `documentation`,
     `blocked`, or an area/stack label the repository already defines.
   - **Priority** (always required when the repository defines priority labels,
     e.g. `P0`, `P1`, `P2`): ask if unclear.
   - **Mode** (whenever it can be judged, and the labels exist): `auto` when the
     work needs little input from the owner and a session can run it end to end;
     `curated` when the owner's input is needed before it can properly start (an
     open design choice, a product call, a hand check that shapes the
     approach). The coordinator (`/coding-master`) starts the two differently.
     If it is unclear, leave it off and say so in the report.
   - **Milestone** — if the caller named one (`--milestone`, or in the
     description) and it exists and is open, use it. Otherwise, if an open
     milestone fits the issue scope (judge by its title, description and due
     date), assign it without asking and name it in the report: a milestone is
     cheap to move, and asking first costs more round-trips than a wrong guess
     ever does. If AGENTS.md has a *Milestones* section (which milestones are
     active, which are backlog), follow it. If none fits, leave it off and say
     so.

8. **Create** — always use `--body-file`:
   ```bash
   gh issue create --title "<title>" --label "<primary>" [--label "<priority>"] [--label "<mode>"] [--milestone "<milestone>"] --body-file /tmp/gh-issue-body.md
   ```
   Include `--milestone` only if one fitted in step 7. Print URL. `rm /tmp/gh-issue-body.md`.

9. **Project board** — only if AGENTS.md has a *Project board* section naming
   the board's owner and number; otherwise skip this step silently. If that
   section says the board adds new issues by itself, there is nothing to do.
   Otherwise:
   ```bash
   gh project item-add <number> --owner <owner> --url <issue-url>
   ```
   If it fails (the token lacks the `project` scope, say), report it with the
   command the developer can rerun; the issue itself is already created.

## rules

- Primary label is always required — never omit it.
- Priority label is always required when the repository defines priority labels — ask the user if unclear.
- Every `feature` issue must have at least one EARS spec in **Done when** — create the spec in `docs/specs/EARS-<subsystem>.md` if it doesn't exist yet.
- Every `bug` issue must name the EARS spec it violates in **Upstream**.
- Acceptance criteria must be testable, not re-statements of the task.
- Annotate problematic lines with `← comment` in code snippets.
- No AI-attribution footers.
- Use `#N` for all GitHub issue references.
