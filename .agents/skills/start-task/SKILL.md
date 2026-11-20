---
name: start-task
description: "Start work on a GitHub issue: reads it with every comment, makes a worktree at the latest default branch, checks the HLD → LLD → EARS spec chain for its subsystem, reports what is ready and what must be written before any code, and creates the branch when the chain is complete. Use for '/start-task [issue]', 'start on issue 42', 'pick up #42', or a coordinator's brief that starts an issue. Not for filing an issue (/issue) or writing the missing docs (/design-docs). Generic copy: if a project skill named `start-task` is also listed, use that one instead."
allowed-tools:
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git grep *)
  - Bash(git rev-parse *)
  - Bash(git symbolic-ref *)
  - Bash(git fetch *)
  - Bash(git pull *)
  - Bash(git branch *)
  - Bash(git switch *)
  - Bash(git checkout *)
  - Bash(git -C * checkout -b *)
  - Bash(git worktree *)
  - Bash(gh api *)
  - Bash(gh issue *)
  - Bash(gh repo *)
  - Bash(${CLAUDE_SKILL_DIR}/../_shared/scripts/worktree.sh *)
  - Bash(${CLAUDE_SKILL_DIR}/../_shared/scripts/spec-ids.sh *)
  - Bash(find *)
  - Bash(grep *)
---

You are a pre-coding gate for this project. Before any code is written, the Arrow of Intent chain must be complete: HLD section → LLD → EARS spec → test plan. Report what is ready and what must be created first.

## Project facts

<!-- facts:begin -->
This is the generic copy: work out the facts below as
[../_shared/facts.md](../_shared/facts.md) says. A row marked *shared* takes
its rule from there.

| Fact | How to find it |
|---|---|
| `<base>` | *shared* |
| wrapper | *shared* |
| setup | *shared* |
| milestones | AGENTS.md *Milestones*: which milestones are active delivery milestones and which are future/backlog ones, or none (skip the milestone warning) |
| skill names | *shared* |
| assets | *shared* |
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

Read the body **and every comment**, and extract:
- Title and body
- Acceptance criteria: task list items (`- [ ]` lines), content under headers such as "Acceptance criteria", "Done when" or "Requirements", and any requirements, edge cases or clarifications added in comments
- Milestone title (if any)

Its **Read first** files are read in step 3, after step 2 updates the checkout.

**Milestone check:** only when the milestones fact tells active delivery milestones apart from future/backlog ones (otherwise skip it). If the issue's milestone is a future/backlog one, put a non-blocking warning in the report and carry on:

> "⚠ Milestone warning: this issue is tagged `<milestone>`, which is a future/backlog milestone. Confirm you intend to work on it now before branching."

## step 2 — sync to the latest default branch, in a new worktree

The spec checks below read the working tree, so a branch that predates a spec merged to the default branch gives false negatives. **Always run this step**, even if a branch for this issue looks current, unless the invocation explicitly says otherwise (e.g. "don't switch branches", "check as-is", "stay on current branch", "skip main sync").

**Work in a new worktree by default**, leaving the primary checkout (which often holds another task's uncommitted work) untouched:

```bash
${CLAUDE_SKILL_DIR}/../_shared/scripts/worktree.sh --wrap '<wrapper>' add task-<N> origin/<base>
```

It fetches, adds a detached worktree at the latest default branch directly
under the primary checkout's `.claude/worktrees/` (random suffix, so two
sessions on the same issue get separate ones), and prints `worktree=<path>`
(`<worktree>` from here on). It prints nothing if git fails.

If the wrapper is a tool-version manager that must trust a new folder before its tools run there, trust `<worktree>` now.

From here on, `<worktree>` — never a worktree nested inside another — is the working directory for every step and for the coding that follows. Continue to step 3.

**Main-worktree mode.** Use the primary checkout instead only when the invocation says so: the developer wants to work in the main worktree (or main checkout), or to test in an editor that has the primary checkout open. Then, in the primary checkout:

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
   If `--ff-only` fails, stop:
   > "Cannot fast-forward `<base>` — local commits exist. Resolve manually before continuing."

## step 3 — identify subsystem

Before proposing any plan, read exactly the files the ticket names under
**Read first** (its scope boundary); if it names none, read those this step's
mapping finds.

Map the issue scope to one or more HLD subsystems by reading `docs/specs/HLD.md`. Find the LLD for each at run time:

1. If `AGENTS.md` has a keyword → LLD table, match its keywords against the issue title and body.
2. Otherwise list the LLDs (`docs/specs/LLD-<subsystem>.md`, named after the HLD subsystem) and match the issue's title, body and named files against each subsystem's name and its HLD *Responsibility* line:
   ```bash
   find docs/specs -name 'LLD-*.md' | sort
   ```

Match specific phrases (for example, "checkout payment") before broad words (for example, "payment"). If the issue matches **several** subsystems, read the relevant sections of each LLD and include findings from each in the report. Ask for clarification only if the dominant subsystem is still unclear after reading the LLDs.

## step 4 — check HLD coverage

Verify `docs/specs/HLD.md` contains a section for the identified subsystem.

- **Present** → continue
- **Missing** → record "`<subsystem>` has no HLD section" and continue.

## step 5 — check LLD existence

Use the exact filename found in step 3. For subsystems the HLD marks *scaffold only*, skip this step.

```bash
find docs/specs -iname "<exact-LLD-filename>"
```

- **Found** → continue
- **Missing** → record "`docs/specs/<exact-LLD-filename>` does not exist" and continue.

## step 6 — check EARS specs

```bash
find docs/specs -iname "EARS-<subsystem>.md"
```

If the spec file exists, search for keywords from the issue title:
```bash
grep -i "<keyword>" docs/specs/EARS-<subsystem>.md
```

If the issue names spec IDs, look each one up across all `docs/specs/EARS-*.md` files, and check which already have tagged tests: `${CLAUDE_SKILL_DIR}/../_shared/scripts/spec-ids.sh --wrap '<wrapper>' tags` lists every `@spec` tag outside `docs/`, `.agents/`, `.claude/` and Markdown as `file:line` and ID (pass the source and test folders AGENTS.md names, when it names them).

**Presenting the specs.** Show the matching specs under a `### Specs to confirm` heading as one table, one row per ID, in the order the EARS files list them:

| ID | Behaviour |
|---|---|
| CART-14 | When a user removes the last item, the cart shows its empty state, clears any applied coupon, zeroes the subtotal and the item count, and keeps the saved-for-later list. |

- Each row restates the spec in plain words as a complete sentence, keeping every condition and outcome; shorten wording, never content.
- Never invent or soften behaviour. Where the spec's wording is unclear or reads oddly, quote it verbatim under the table.
- Above the table, name the EARS file each ID prefix comes from, and say which IDs already have tagged tests.
- Below the table, list every gap — a requirement in the issue or its comments that no listed spec covers, and any named spec that does not exist — as a question for the developer, never resolved silently.

Report:
- **Matching spec IDs found** → present them as above, then ask:
  > "Do these specs cover the intended behaviour for this task? (yes / no — refine or add specs first)"
  - **yes** → continue to step 7
  - **no** → record "the specs need refining or adding in `docs/specs/EARS-<subsystem>.md`" and continue.
- **Spec file exists, no match** → record "no EARS spec for this behaviour in `docs/specs/EARS-<subsystem>.md`" and continue.
- **Spec file missing** → record "`docs/specs/EARS-<subsystem>.md` does not exist" and continue.

Steps 4–6 never stop on their own: each gap is recorded and the run goes on, skipping only a check that needs a missing file, so step 8 reports every gap at once.

## step 7 — suggest branch name

Name it as [../_shared/git-conventions.md](../_shared/git-conventions.md) says.

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

If HLD, LLD, or EARS specs are missing, always output "Stop" — never suggest coding without them. On a Stop, leave the step 2 worktree in place and name its path (`<worktree>`): the `/design-docs` work happens there.

## step 9 — branch setup (chain complete only)

Create the branch without asking, unless the invocation names another branch or says not to create one.

1. Create and switch to the feature branch. `<dir>` is `<worktree>`, or the primary checkout's path in main-worktree mode:
   ```bash
   git -C <dir> checkout -b <branch-name>
   ```

2. A worktree lacks git-ignored files (installed dependencies, generated code). Before the first quality gate, run the setup fact's steps in `<worktree>`; when AGENTS.md says nothing needs setting up, there is nothing to run. When AGENTS.md has no *Worktree setup* at all, apply the *Setup* section of each loaded stack asset: show the developer the steps it suggests for this repository, ask whether to run them, and suggest recording the agreed steps in AGENTS.md *Worktree setup*. Never run them unasked on a guess. If a setup step fails, stop and report it; do not work around it.

3. Confirm:
   > "On `<branch-name>` at `<short-sha>` in `<worktree path, or 'the primary checkout'>`. Ready to code."

If the invocation said not to create it, output:
> "When ready: `git -C <worktree> checkout -b <branch-name>`" — or, in main-worktree mode, "`git checkout <base> && git pull --ff-only origin <base> && git checkout -b <branch-name>`".
