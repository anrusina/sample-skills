---
name: issue
description: "File a GitHub issue that traces back through the Arrow of Intent: reads the HLD, LLDs, EARS specs and, for a bug, the source; checks for duplicates; writes the body from a bug, feature, spike or design template with testable Done-when criteria (new specs as provisional IDs); and picks existing labels and a milestone. Writes no files. Use whenever a bug, feature, follow-up or investigation should be tracked: 'open an issue', 'file a bug', 'log this for later', 'make a ticket'. Not for triaging user feedback (/feedback-review) or planning a phase (/managerial). Generic copy: if a project skill named `issue` is also listed, use that one instead."
model: haiku
---

You file GitHub issues for this project. Every issue traces back through the Arrow of Intent chain (HLD → LLDs → EARS Specs → Tests → Code): it references existing upstream artifacts or names what must be written first.

## Project facts

<!-- facts:begin -->
This is the generic copy: work out the facts below as
[../_shared/facts.md](../_shared/facts.md) says. A row marked *shared* takes
its rule from there.

| Fact | How to find it |
|---|---|
| wrapper | *shared* |
| labels | `gh label list --limit 100`, read at run time: the type, priority and mode labels the repository defines |
| milestones | AGENTS.md *Milestones*: which milestones are active and which are backlog, and the rule for choosing one, or none (judge by the open milestones' titles, descriptions and due dates) |
| project board | AGENTS.md *Project board*: the board's owner and number, and whether it adds new issues by itself, or none (skip step 9) |
| skill names | *shared* |
| assets | *shared* |
<!-- facts:end -->

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

1. **Context** — `git branch --show-current`. Read `docs/specs/HLD.md` to identify the relevant subsystem.

2. **Locate upstream** — find the relevant HLD section. List `docs/specs/LLD-*.md` and match the HLD's subsystem name to find the LLD covering this subsystem (if AGENTS.md has a keyword-to-LLD table, use it). Check `docs/specs/EARS-<subsystem>.md` for related EARS spec IDs.

   These feed two sections. **Upstream** records traceability, including spec
   IDs and anything still to be written. **Read first** names only existing
   *documents* (not spec IDs, which go stale) that bear on the work, and
   nothing more: `/start-task` reads exactly this list as the scope boundary.
   Always keep the `AGENTS.md` row.

3. **For `bug` and `feature`** — read the referenced source file(s) first, always for a bug. Extract a 5–20 line snippet where relevant. Apply the *Current code* section of each loaded field asset.

4. **Duplicates** — `gh issue list --search "<keyword>" --state open --json number,title --limit 10`. If a match exists, report and stop.

5. **Body** — load [assets/templates/<type>.md](assets/templates/) for the resolved type and fill it in. For a `feature` or a `bug`, add to **Done when** the lines from the *Done when* section of each loaded field asset that bear on the work, below the template's own lines. For a `bug`, apply the *Upstream* section of each loaded field asset. The filled body goes into the step 8 command.

6. **Title** — imperative verb phrase for `feature`/`bug`/`design`; question or noun phrase for `spike`. Max ~80 chars.

7. **Labels and milestone** — fetch current values on every run:
   ```bash
   gh label list --limit 100
   gh api 'repos/{owner}/{repo}/milestones' --jq '.[] | {title, description, due_on}'
   ```
   Use existing labels and milestones only — never create one unasked.
   - **Primary** (always required): `feature`, `bug`, `spike`, or `design`.
     If the repository names it differently (`enhancement` for `feature`,
     `documentation` for `design`), use the existing label that means the
     same. If none exists, ask the developer once whether to create it.
   - **Secondary** (add as applicable, when the label exists): `documentation`,
     `blocked`, or an area/stack label the repository already defines. Apply
     the *Labels* section of each loaded field asset.
   - **Priority** (always required when the repository defines priority labels,
     e.g. `P0`, `P1`, `P2`): ask if unclear.
   - **Mode** (whenever it can be judged, and the labels exist): `auto` when the
     work needs little input from the owner and a session can run it end to end;
     `curated` when the owner's input is needed before it can properly start (an
     open design choice, a product call, a hand check that shapes the
     approach). If it is unclear, leave it off and say so in the report.
   - **Milestone** — if the caller named one (`--milestone`, or in the
     description) and it exists and is open, use it. Otherwise, if an open
     milestone fits the issue scope (judge by its title, description and due
     date), assign it without asking and name it in the report. When the
     milestones fact gives a rule (which milestones are active, which are
     backlog), follow it. If none fits, leave it off and say so.

8. **Create** — always use `--body-file`, with a fresh `mktemp` file (never a
   fixed path), written, used and removed in one Bash call:
   ```bash
   BODY=$(mktemp) && trap 'rm -f "$BODY"' EXIT
   cat > "$BODY" <<'ISSUE_BODY'
   <the filled body from step 5>
   ISSUE_BODY
   gh issue create --title "<title>" --label "<primary>" [--label "<priority>"] [--label "<mode>"] [--milestone "<milestone>"] --body-file "$BODY"
   ```
   Include `--milestone` only if one fitted in step 7. Print URL.

9. **Project board** — only if the project board fact names the board's owner
   and number (otherwise skip silently) and the board does not add new issues
   by itself:
   ```bash
   gh project item-add <number> --owner <owner> --url <issue-url>
   ```
   If it fails (the token lacks the `project` scope, say), report it with the
   command the developer can rerun; the issue itself is already created.

## rules

- Every `feature` issue has at least one EARS spec line in **Done when**. A spec that doesn't exist yet is written there with a provisional ID (the next free one in its namespace, marked *provisional*), and created in `docs/specs/` when the work starts (`/start-task`, `/design-docs`), not now: filing an issue writes no file.
- Every `bug` issue names the EARS spec it violates in **Upstream**. When no spec covers the behaviour, say so there, as the Arrow of Intent's missing-intent case, and make writing that spec part of **Done when**.
- Acceptance criteria are testable, not re-statements of the task: `/start-task` turns them into specs and tests.
- Annotate problematic lines with `← comment` in code snippets.
- No AI-attribution footers.
- Use `#N` for all GitHub issue references.
