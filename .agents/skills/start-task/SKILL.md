---
name: start-task
description: "Pre-coding checklist — fetch the issue, verify HLD → LLD → EARS spec chain, identify what must be written before any code is touched. Trigger: /start-task <N>, or a request (from the developer or a coordinator's brief) to start work on a GitHub issue. Generic template: a project's own `start-task` skill takes precedence."
allowed-tools:
  - Bash(git *)
  - Bash(gh api *)
  - Bash(gh issue *)
  - Bash(gh repo *)
  - Bash(${CLAUDE_SKILL_DIR}/scripts/worktree.sh *)
  - Bash(${CLAUDE_SKILL_DIR}/scripts/spec-ids.sh *)
  - Bash(find *)
  - Bash(grep *)
---

You are a pre-coding gate for this project. Before any code is written, the Arrow of Intent chain must be complete: HLD section → LLD → EARS spec → test plan. Report what is ready and what must be created first.

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
| wrapper | AGENTS.md build section: the prefix the toolchain runs through (a version manager's exec command, for example), or none. Run the gates, and each tool the wrapper provides (the tools its config file lists), through it; pass it to this skill's scripts as `--wrap '<wrapper>'`; run every other command bare, so it matches `allowed-tools` |
| setup | AGENTS.md *Worktree setup*: the steps a fresh worktree needs (dependencies, code generation), or none |
| milestones | AGENTS.md *Milestones*: which milestones are active delivery milestones and which are future/backlog ones, or none (skip the milestone warning) |
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

`$ARGUMENTS`: a GitHub issue number or URL. **Required.** If omitted, stop:
> "Provide an issue number: `/start-task 42`"

## step 0 — read AGENTS.md first

Read **`AGENTS.md`** before fetching anything or forming any plan — read it,
don't recall it. Order: `AGENTS.md` → ticket (step 1) → upstream docs.

## step 1 — fetch and read the issue

Write the issue number in for `<N>`; `gh` fills `{owner}` and `{repo}` itself.

```bash
gh api 'repos/{owner}/{repo}/issues/<N>' --jq '{title, body, labels: [.labels[].name], milestone: .milestone.title}'
gh api 'repos/{owner}/{repo}/issues/<N>/comments' --paginate --jq '.[] | .body + "\n---"'
```

Extract from both the issue body **and all comments**:
- Issue title and body
- Task list items (`- [ ]` lines) — these are the acceptance criteria
- Any content under headers named "Acceptance criteria", "Done when", or "Requirements"
- Milestone title (if any)
- Comments may contain additional requirements, edge cases, or clarifications added after the issue was written — treat them as part of the acceptance criteria

**Milestone check:** only when the milestones fact tells active delivery milestones apart from future/backlog ones. If the issue's milestone is a future/backlog one by that rule, emit a non-blocking warning in the report:

> "⚠ Milestone warning: this issue is tagged `<milestone>`, which is a future/backlog milestone. Confirm you intend to work on it now before branching."

Do not stop — this is a warning only. When the milestones fact is none, skip the check and give no warning.

Read the ticket in full: body and every comment. Its **Read first** files are
read in step 3, once step 2 has brought the checkout up to date.

## step 2 — sync to the latest default branch, in a new worktree

The HLD/LLD/EARS checks in the steps below read spec files from the working tree. If the current branch predates a spec update merged to the default branch (e.g. another CLI session added EARS specs for this issue), the checks will report false negatives. Sync to the latest default branch first so the readiness report reflects the current canonical state.

**Skip this step only if the invocation explicitly says otherwise** (e.g. "don't switch branches", "check as-is", "stay on current branch", "skip main sync"). Otherwise always run it, even if a branch for this issue already looks current.

**Work in a new worktree by default.** The primary checkout routinely holds uncommitted work from another task or session, so leave it untouched:

```bash
${CLAUDE_SKILL_DIR}/scripts/worktree.sh --wrap '<wrapper>' add task-<N> origin/<base>
```

It fetches, adds a detached worktree at the latest default branch directly
under the primary checkout's `.claude/worktrees/` (with a random suffix, so
two sessions starting the same issue get separate ones), and prints
`worktree=<path>`, which is `<worktree>` from here on. It prints nothing if
git fails.

If the wrapper is a tool-version manager that must trust a new folder before its tools run there, trust `<worktree>` now; otherwise every wrapped command in it fails.

From here on, `<worktree>` — always directly under the primary checkout's `.claude/worktrees/`, never inside another worktree — is the working directory for every step and for the coding that follows. Nothing in the primary checkout is touched, so there is no uncommitted-changes check. Continue to step 3.

**Main-worktree mode.** Use the primary checkout instead only when the invocation says so: the developer wants to work in the main worktree (or main checkout), or wants to test the work in an editor that has the primary checkout open. Then run the steps below in the primary checkout.

1. Check for uncommitted changes:
   ```bash
   git status --short
   ```
   If anything is uncommitted, stop: "Uncommitted changes present on `<branch>`. Commit them, ask me to work in a new worktree instead, or ask me to skip the sync before continuing."

2. Note current branch:
   ```bash
   git rev-parse --abbrev-ref HEAD
   ```

3. If not already on the default branch, switch:
   ```bash
   git checkout <base>
   ```

4. Pull latest:
   ```bash
   git pull --ff-only origin <base>
   ```
   If `--ff-only` fails (the local default branch has diverged), stop:
   > "Cannot fast-forward `<base>` — local commits exist. Resolve manually before continuing."

Continue to step 3 with the default branch checked out and current.

## step 3 — identify subsystem

First read exactly the files the ticket names under **Read first** (its
scope boundary), from the up-to-date checkout; if it names none, read those
this step's mapping finds. Read them before proposing any plan.

Map the issue scope to one or more HLD subsystems by reading `docs/specs/HLD.md`. Find the LLD for each at run time:

1. If `AGENTS.md` has a keyword → LLD table, match its keywords against the issue title and body and use it.
2. Otherwise list the LLDs and match against the HLD's subsystem names:
   ```bash
   find docs/specs -name 'LLD-*.md' | sort
   ```
   An LLD is `docs/specs/LLD-<subsystem>.md`, named after the HLD subsystem. Match the issue's title, body and named files against each subsystem's name and its HLD *Responsibility* line.

Match specific phrases (for example, "checkout payment") before broad words (for example, "payment"). If a single subsystem matches clearly, use it. If the issue matches **several** (e.g. "fix cart totals at checkout" hits both `cart` and `checkout`), check each LLD — read the relevant sections and include findings from each in the report. Only ask for clarification if the dominant subsystem is genuinely unclear after reading the LLDs.

## step 4 — check HLD coverage

Verify `docs/specs/HLD.md` contains a section for the identified subsystem.

- **Present** → continue
- **Missing** → record "`<subsystem>` has no HLD section" and go to step 8, which ends with Stop.

## step 5 — check LLD existence

Use the exact filename found in step 3 rather than a glob. For subsystems the HLD marks *scaffold only*, skip this step.

```bash
find docs/specs -iname "<exact-LLD-filename>"
```

- **Found** → continue
- **Missing** → record "`docs/specs/<exact-LLD-filename>` does not exist" and go to step 8, which ends with Stop.

## step 6 — check EARS specs

```bash
find docs/specs -iname "EARS-<subsystem>.md"
```

If the spec file exists, search for keywords from the issue title:
```bash
grep -i "<keyword>" docs/specs/EARS-<subsystem>.md
```

If the issue names spec IDs, look each one up directly across all `docs/specs/EARS-*.md` files, and also check which already have tagged tests: `${CLAUDE_SKILL_DIR}/scripts/spec-ids.sh --wrap '<wrapper>' tags` lists every `@spec` tag outside `docs/`, `.agents/`, `.claude/` and Markdown as `file:line` and ID (pass the source and test folders AGENTS.md names, when it names them).

**Presenting the specs.** Show the matching specs under a `### Specs to confirm` heading as one table, one row per ID, in the order the EARS files list them:

| ID | Behaviour |
|---|---|
| CART-14 | When a user removes the last item, the cart shows its empty state, clears any applied coupon, zeroes the subtotal and the item count, and keeps the saved-for-later list. |

- Each row is a short plain-words restatement of the spec, written as a complete sentence, so the developer can judge coverage without opening the file. Keep every condition and every outcome the spec states; shorten wording, never content.
- Never invent or soften behaviour. Where the spec's own wording is unclear or reads oddly, quote it verbatim under the table instead of smoothing it over.
- Above the table, name the EARS file each ID prefix comes from, and say which IDs already have tagged tests.
- Below the table, list every gap: a requirement in the issue body or its comments that no listed spec covers, and any spec the issue names that does not exist. A gap is a question for the developer, not something to resolve silently.

Report:
- **Matching spec IDs found** → present them as above, then ask:
  > "Do these specs cover the intended behaviour for this task? (yes / no — refine or add specs first)"
  - **yes** → continue to step 7
  - **no** → record "the specs need refining or adding in `docs/specs/EARS-<subsystem>.md`" and go to step 8.
- **Spec file exists, no match** → record "no EARS spec for this behaviour in `docs/specs/EARS-<subsystem>.md`" and go to step 8.
- **Spec file missing** → record "`docs/specs/EARS-<subsystem>.md` does not exist" and go to step 8.

Steps 4–6 never stop on their own: a gap is recorded and the run goes to step 8, so the developer always gets the full report with every gap at once, and the worktree's path.

## step 7 — suggest branch name

```
feature-<N>/<3-5-word-slug>   # new functionality
fix-<N>/<3-5-word-slug>        # bug fixes
spike-<N>/<3-5-word-slug>      # research / investigation
docs-<N>/<3-5-word-slug>       # documentation only
```

## step 8 — output the readiness report

```
## <Ready to start | Not ready>: #<N> — <issue title>

### Subsystem: <name>

### Arrow of Intent
- [✓/✗] HLD section: <section name or "missing">
- [✓/✗] LLD: <filename or "missing">
- [✓/✗] EARS specs: <IDs or "missing">

### Milestone
<milestone name, or "none"> <warning line if future milestone>

### Acceptance criteria
<task list items from the issue body, or "None found — confirm scope before starting">

### Specs to confirm
<the table and gap list from step 6>

### Component catalog
<only when AGENTS.md names a component catalog — omit the section otherwise>
If this issue codes any screen or reusable component: plan its catalog coverage
following AGENTS.md — every state named in the backing LLD must have an entry,
including each failure state, wherever AGENTS.md says failure states are also registered.

### Test tiers
<only when AGENTS.md's testing section (*Testing*) defines test tiers or file-level test tags — omit the section otherwise>
For each test file this issue adds, name its tier, chosen by the rule AGENTS.md
gives, and any extra tag it requires (e.g. for tests that read local-only fixtures).
For a test added to an existing file, name the tier only if the test clears a
higher bar than its file's.

### Suggested branch
<branch-name>

### Next step
<exactly one of the two lines below>
```

End with exactly one of:
- "Chain complete. Write a failing test tagged `// @spec <ID>` (in a test file that carries its tier, where the project uses tiers), then implement."
- "Stop — <list what is missing>. Run `/design-docs` to create the missing artifacts first."

If HLD, LLD, or EARS specs are missing: always output "Stop". Never suggest starting to code without HLD, LLD, and EARS specs. On a Stop, leave the step 2 worktree in place and name its path (`<worktree>`) — the `/design-docs` work for the missing artifacts happens there.

## step 9 — branch setup (chain complete only)

Only run this step if step 8 ended with "Chain complete."

Create the branch without asking, unless the invocation names another branch or says not to create one: the name follows the project's convention, and a coordinator's brief would otherwise stall on the question.

1. Create and switch to the feature branch (step 2 already put you on the latest default branch — in `<worktree>`, or in the primary checkout in main-worktree mode). `<dir>` is `<worktree>`, or the primary checkout's path in main-worktree mode:
   ```bash
   git -C <dir> checkout -b <branch-name>
   ```

2. In a worktree, git-ignored files are absent: installed dependencies and any generated code. Before the first quality gate, run the setup fact's steps in `<worktree>`. When the setup fact is none because AGENTS.md says nothing needs setting up, there is nothing to run. When AGENTS.md has no *Worktree setup* at all, apply the *Setup* section of each loaded stack asset: show the developer the steps it suggests for this repository, ask whether to run them, and suggest recording the agreed steps in AGENTS.md *Worktree setup*. Never run them unasked on a guess. If a setup step fails, stop and report it; do not work around it.

3. Confirm:
   > "On `<branch-name>` at `<short-sha>` in `<worktree path, or 'the primary checkout'>`. Ready to code."

If the invocation said not to create it, output:
> "When ready: `git -C <worktree> checkout -b <branch-name>`" — or, in main-worktree mode, "`git checkout <base> && git pull --ff-only origin <base> && git checkout -b <branch-name>`".
