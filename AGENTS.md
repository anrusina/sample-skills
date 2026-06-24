# {Project name}

{One paragraph description of the project.}

---

## Arrow of Intent (MANDATORY)

All changes must originate from intent and flow downstream. Never write code without upstream documentation in place.

```
HLD → LLDs → EARS Specs → Tests → Code
```

**Before any code change, check:**
1. Does the HLD cover this subsystem?
2. Is there an LLD for this subsystem?
3. Is there an EARS spec for this specific behaviour?
4. Is there a test tagged with that spec ID?

If any answer is no — stop and create the missing upstream artifact first.

**New feature:** run `/start-task <issue-number>` → it checks HLD → LLD → EARS spec chain → write failing test → implement code.

### LLD altitude — UI boundary

LLDs capture **behaviour, data structures, inputs/outputs, state machines, contracts, and what/when information is shown** — anything that can be expressed as an EARS spec and tested.

LLDs must **not** pin look-and-feel: exact colours, sizes, fonts, icon glyphs, animation style, or pixel layout. Those belong in wireframes (`docs/design/`) or the design system. Use named design-system tokens to reference values if needed; never hardcode literals in an LLD.

The `arrow-check` and `doc-audit` skills enforce this boundary during review.

**Bug fix:** trace up the arrow to where intent was missing or wrong. Fix the doc first, update the spec, fix the test, then fix the code.

**Changing requirements:** update HLD or LLD first, cascade down through specs → tests → code. Mutation, not accumulation — docs must always reflect current intent.

---

## EARS spec format

Specs live in `docs/specs/<subsystem>-specs.md` (alongside HLD and LLDs). Each spec has a unique ID and follows this format:

```
SUBSYSTEM-NNN: When [condition], the system shall [action].
```

Examples:
```
GRID-001: When a user confirms a selection, the system shall mark all selected cells as done.
AUTH-001: When a user submits invalid credentials, the system shall display an error and clear the password field.
```

Tag tests and code with the spec ID:
```
// @spec GRID-001
test('confirm selection marks all selected cells as done', () { ... });
```

---

## Project structure

```
.agents/
  skills/
    <name>/SKILL.md     ← AI workflow skills (Agent Skills standard)
docs/
  specs/
    HLD.md              ← system architecture (read this first)
    LLD-*.md            ← one LLD per subsystem
    *-specs.md          ← EARS specs per subsystem
  design/               ← UI/UX artefacts (wireframes, prototypes, screen maps)
  spikes/
    *.md                ← research findings
lib/                    ← source code  # TODO: adjust to your project layout
test/                   ← tests tagged with @spec IDs
```

---

## Agent Skills

Reusable workflow skills live in `.agents/skills/<name>/SKILL.md`, following the [Agent Skills](https://agentskills.io) open standard. Compatible with Claude Code, Codex, GitHub Copilot, and other agent tools.

Before starting a workflow task (commits, PRs, reviews, issues, doc/design work), scan `.agents/skills/` and, when a skill's `description` matches the task, load its `SKILL.md` and follow it.

---

## Build and test commands

```bash
# TODO: replace with your project's commands
# Format, lint, and test should all be runnable from the repo root.
```

---

## Code style

<!-- TODO: add 3–5 project-specific rules only. Omit anything the language toolchain enforces automatically. -->

---

## Testing

All tests must carry a spec ID tag on the line before the test call:

```
// @spec SUBSYSTEM-NNN
test('description', () { ... });
```

- One `// @spec` tag per test. Multiple specs covered → multiple tests.
- No mocking of internal collaborators — use real objects or test fakes. External dependencies (filesystem, network) may be mocked.

---

## AI skills and workflow

| Task | Skill |
|---|---|
| **Start any code task** | `/start-task` |
| Write a commit message | `/commit` |
| Commit and open a PR | `/commit-and-pr` |
| Open a PR | `/pr` |
| Review a PR | `/review-pr` |
| Fix review findings | `/fix-pr-findings` |
| Pre-merge cleanup | `/pre-merge` |
| Create an issue | `/issue` |
| Validate design chain | `/arrow-check` |
| Write/update design docs | `/design-docs` |
| Audit documentation | `/doc-audit` |
| End a CLI session | `/close-cli` |

---

## Security

### Dependency policy

Before adding any package:

1. Verify the specific version being added has been published for at least **14 days**.
2. Check the package's source repo for unusual recent commits, new maintainers, or activity spikes.
3. Never add a package published less than 14 days ago, regardless of how well-known the author is.

---

## Working style

- Present multiple options with tradeoffs before any architectural decision.
- State scope explicitly — what is in and what is out — for every task.
- If scope is unclear, ask before proceeding.
- When in doubt, read the HLD first.
