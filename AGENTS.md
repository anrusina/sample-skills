# {Project name}

{One paragraph description of the project.}

<!--
This file is the template a project copies to its root and fills in. The
generic skills (the sample-skills plugin) read the sections below to find the
project's own facts (quality gates, worktree setup, pre-merge checks, project
board…). They match a section by what it holds, so a heading can be renamed,
but keeping these names makes the match certain. A section marked "optional"
can be deleted; the skills then skip the steps that need it. /setup-skills
reads the same sections when it writes these facts into a project's own copy
of the skills. Delete this comment once filled.
-->

---

## Where to start

1. Read `docs/specs/HLD.md` — system architecture and data model
2. Read the LLD for the subsystem you are touching (`docs/specs/LLD-<subsystem>.md`)

---

## Arrow of Intent (MANDATORY)

All changes must originate from intent and flow downstream. Never write code without upstream documentation in place.

```
HLD → LLDs → EARS Specs → Tests → Code
```

EARS requirements are derived from the HLD and LLDs. The HLD does not cite downstream EARS files or requirement IDs. An LLD may link to its EARS file and name requirement namespaces (for example `AUTH-NNN`) as navigation aids, but must not map its sections to individual EARS IDs.

**Before any code change, check:**

1. Does the HLD cover this subsystem?
2. Is there an LLD for this subsystem?
3. Is there an EARS spec for this specific behaviour?
4. Is there a test tagged with that spec ID?

If any answer is no — stop and create the missing upstream artifact first.

### LLD altitude — UI boundary

LLDs capture **behaviour, data structures, inputs/outputs, state machines, derivation rules, contracts, and what/when information is shown** — anything that can be expressed as an EARS spec and tested.

LLDs must **not** pin look-and-feel: exact string wording, colors, sizes, fonts, icon glyphs, animation style, or pixel layout. Those belong in the design system. Naming a design-system token is fine; restating its literal value is drift.

**Rule of thumb:** if changing it doesn't change behaviour, data flow, or testable logic — it's UI. Leave it out, or mark it `<!-- UI concern -->` if the context makes it unavoidable.

**Cross-LLD ownership:** each LLD describes only its own subsystem's slice of a cross-cutting concern, and links to the others instead of paraphrasing them.

The `arrow-check` and `doc-audit` skills enforce this boundary during review.

### LLD telemetry signals

An LLD that documents log events with product intelligence includes a `## Telemetry signals` section: a denominator event (the happy-path event) first, then failure signals measured as a rate against it.

| Signal | Level | Emitted when | Product intelligence | Pairs with |
|---|---|---|---|---|
| `checkout_attempted` | `info` | user submits an order | denominator for checkout failures | — |
| `payment_declined` | `warning` | the payment provider declines | rate = payment-friction signal | `checkout_attempted` |

**New feature:** run `/start-task <issue-number>` → it checks the HLD → LLD → EARS chain and tells you what to create first → write a failing test → implement.

**Bug fix:** trace up the arrow to where intent was missing or wrong. Fix the doc first, update the spec, fix the test, then fix the code.

**Changing requirements:** update the HLD or LLD first, cascade down through specs → tests → code. Mutation, not accumulation — docs always reflect current intent.

---

## EARS spec format

Specs live in `docs/specs/EARS-<subsystem>.md`. Each spec has a unique ID and follows this format:

```
SUBSYSTEM-NNN: When [condition], the system shall [action].
```

Examples:
```
AUTH-001: When a user submits invalid credentials, the system shall show an error and clear the password field.
CART-002: When a user removes the last item from the cart, the system shall show the empty-cart state.
```

Tag tests with the spec ID on the line before the test:
```
// @spec AUTH-001
test('invalid credentials show an error and clear the password', () { ... });
```

### Scope-boundary notes

When an EARS file must say what its subsystem does NOT do, because the concern belongs elsewhere, use a `> Note:` blockquote with no spec ID. State only this subsystem's absence and link to where the reader should look; never narrate the other subsystem's internals.

---

## Project structure

```
.agents/skills/<name>/SKILL.md   ← AI workflow skills (Agent Skills standard)
.claude/skills -> ../.agents/skills
docs/
  specs/     ← HLD.md, LLD-<subsystem>.md, EARS-<subsystem>.md
  design/    ← UI/UX artefacts
  spikes/    ← research findings
  dev/       ← developer reference
src/         ← source code   {adjust to your layout}
test/        ← tests, tagged with @spec IDs
```

{If any Markdown feeds the build (a content collection, a docs site), name its
paths here: the skills then never treat a change to it as documentation-only.}

---

## Agent Skills

Reusable workflow skills live in `.agents/skills/<name>/SKILL.md`, following the [Agent Skills](https://agentskills.io) open standard. The same files work across Claude Code, Codex, Copilot, and other agents.

Before starting a workflow task (commits, PRs, reviews, issues, doc/design work), scan `.agents/skills/` and, when a skill's `description` matches the task, load its `SKILL.md` and follow it.

---

## Build and test commands

The quality gates `/commit` and `/pre-merge` run, in order. Any failure blocks a commit.

```bash
{format command}        # e.g. the formatter, in check mode
{lint command}          # static analysis — any issue blocks
{test command}          # the full test suite
```

{If the format gate only checks, also give the write-mode command (e.g. the
same formatter without its check flag); `/commit` uses it to fix formatting
and re-run the gate.}

{If tools must run through a wrapper — a version manager's exec command, a
container — say so here; the skills then prefix every tool command with it.}

### Worktree setup (optional)

Commands a fresh git worktree needs before the gates pass (dependency install,
code generation, trusting the tool-version config). `/start-task` and
`/coding-master` run them in each new worktree, `/review-pr` in its review
worktree, and `/pre-merge` again after rebasing.

---

## Pre-merge checks (optional)

Checks `/pre-merge` runs after the rebase, beyond the quality gates: slow or
fixture-based test suites, a clean-checkout CI-equivalent run, a version bump,
release notes. List each with its command and when it applies.

---

## Releases (optional)

What a merge to the default branch deploys or publishes, and how to check it
succeeded. `/coding-master` checks it after each merge.

---

## Project board (optional)

GitHub project board that new issues and PR-linked issues go on: owner and
project number (from the project URL). Without this section the skills skip
every board step.

## Milestones (optional)

Which milestones are active delivery milestones and which are backlog, so
`/start-task` can warn before work starts on a backlog issue and `/managerial`
and `/feedback-review` know where deferred work goes.

## Feedback (optional)

The labels that mark user-feedback issues, and the milestone new feedback
lands in, for `/feedback-review`.

---

## Code style

{3–5 project-specific rules only. Omit anything the toolchain enforces.}

---

## Testing

All tests carry a spec ID tag on the line before the test call:

```
// @spec SUBSYSTEM-NNN
test('description', () { ... });
```

- One `// @spec` tag per test. Multiple specs covered → multiple tests.
- No mocking of internal collaborators — use real objects or test fakes. External dependencies (filesystem, network) may be mocked.
- {Optional: test tiers, how to choose one, and the fast subset command.}

---

## AI skills and workflow

| Task | Skill |
|---|---|
| **Start any code task** | `/start-task` |
| Write a commit | `/commit` |
| Commit and open a PR | `/commit-and-pr` |
| Open a PR | `/pr` |
| Review a PR | `/review-pr` |
| Fix review findings | `/fix-pr-findings` |
| Pre-merge cleanup | `/pre-merge` |
| Create an issue | `/issue` |
| Validate design chain | `/arrow-check` |
| Write/update design docs | `/design-docs` |
| Audit documentation | `/doc-audit` |
| Full documentation pass | `/doc-audit-full` |
| Triage feedback issues | `/feedback-review` |
| Coordinate task and reviewer sessions | `/coding-master` |
| Plan and manage a delivery phase | `/managerial` |

`/setup-skills` (from the sample-skills plugin) brings these skills into the
project and keeps the copy current; it is never copied in itself.

Commits carry no AI attribution trailer unless this file asks for one.

---

## Security

### Dependency policy

Before adding any package:

1. Verify the specific version being added has been published for at least **14 days**.
2. Check the package's source repo for unusual recent commits, new maintainers, or activity spikes.
3. Record the check as a comment next to the dependency in the manifest.
4. Never add a package published less than 14 days ago, regardless of how well-known the author is.

---

## Working style

- Present multiple options with tradeoffs before any architectural decision. List the **Ideal** fix first, then the **Shortcut**, and say what the shortcut gives up.
- State scope explicitly — what is in and what is out — for every task.
- If scope is unclear, ask before proceeding.
- When in doubt, read the HLD first.
