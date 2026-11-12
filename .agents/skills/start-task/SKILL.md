---
name: start-task
description: "Pre-coding checklist — fetch the issue, verify HLD → LLD → EARS spec chain, identify what must be written before any code is touched. Trigger: /start-task <N>, or a request (from the developer or a coordinator's brief) to start work on a GitHub issue. Generic template: a project's own `start-task` skill takes precedence."
allowed-tools:
  - Bash(git *)
  - Bash(gh api *)
  - Bash(gh issue *)
  - Bash(gh repo *)
  - Bash(find *)
  - Bash(grep *)
---

You are a pre-coding gate for this project. Before any code is written, the Arrow of Intent chain must be complete: HLD section → LLD → EARS spec → test plan. Report what is ready and what must be created first.

## input

`$ARGUMENTS`: a GitHub issue number or URL. **Required.** If omitted, stop:
> "Provide an issue number: `/start-task 42`"

## step 0 — read AGENTS.md first

Read **`AGENTS.md`** before fetching anything or forming any plan — read it,
don't recall it. Order: `AGENTS.md` → ticket (step 1) → upstream docs.

If `AGENTS.md` *Build and test commands* says tools run through a wrapper (for
example a version manager's exec command), prefix every tool command in this
skill with it.

## step 1 — fetch and read the issue

```bash
OWNER_REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
gh api repos/${OWNER_REPO}/issues/${NUMBER} --jq '{title, body, labels: [.labels[].name], milestone: .milestone.title}'
gh api repos/${OWNER_REPO}/issues/${NUMBER}/comments --paginate --jq '.[] | .body + "\n---"'
```

Extract from both the issue body **and all comments**:
- Issue title and body
- Task list items (`- [ ]` lines) — these are the acceptance criteria
- Any content under headers named "Acceptance criteria", "Done when", or "Requirements"
- Milestone title (if any)
- Comments may contain additional requirements, edge cases, or clarifications added after the issue was written — treat them as part of the acceptance criteria

**Milestone check:** only when `AGENTS.md` has a *Milestones* section that tells active delivery milestones apart from future/backlog ones. If the issue's milestone is a future/backlog one by that section's rule, emit a non-blocking warning in the report:

> "⚠ Milestone warning: this issue is tagged `<milestone>`, which is a future/backlog milestone. Confirm you intend to work on it now before branching."

Do not stop — this is a warning only. Without a *Milestones* section, skip the check and give no warning.

Read the ticket in full — body and every comment. Then read exactly the
files it names under **Read first** (its scope boundary), or, if it names
none, those from the step 3 mapping — before proposing any plan.

## step 2 — sync to the latest default branch, in a new worktree

The HLD/LLD/EARS checks in the steps below read spec files from the working tree. If the current branch predates a spec update merged to the default branch (e.g. another CLI session added EARS specs for this issue), the checks will report false negatives. Sync to the latest default branch first so the readiness report reflects the current canonical state.

**Skip this step only if the invocation explicitly says otherwise** (e.g. "don't switch branches", "check as-is", "stay on current branch", "skip main sync"). Otherwise always run it, even if a branch for this issue already looks current.

**Work in a new worktree by default.** The primary checkout routinely holds uncommitted work from another task or session, so leave it untouched:

```bash
BASE=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null \
  || git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')
git fetch origin
# The primary checkout, wherever this session runs: started inside another
# worktree, a relative path would nest the new one under it.
ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
WT="$ROOT/.claude/worktrees/task-<N>-<suffix>"
git worktree add --detach "$WT" "origin/$BASE"
```

If the project uses a tool-version manager that must trust a new folder before its tools run there (`AGENTS.md` *Build and test commands*), trust `$WT` now; otherwise every wrapped command in it fails.

`<suffix>` is 6 random hex characters you pick, so two sessions starting the same issue get separate worktrees. From here on, `$WT` — always directly under the primary checkout's `.claude/worktrees/`, never inside another worktree — is the working directory for every step and for the coding that follows. Nothing in the primary checkout is touched, so there is no uncommitted-changes check. Continue to step 3.

**Main-worktree mode.** Use the primary checkout instead only when the invocation says so: the developer wants to work in the main worktree (or main checkout), or wants to test the work in an editor that has the primary checkout open. Then run the steps below, with `$BASE` set as above.

1. Check for uncommitted changes:
   ```bash
   git status --short
   ```
   If anything is uncommitted, stop: "Uncommitted changes present on `<branch>`. Commit, stash, or ask me to skip the sync before continuing."

2. Note current branch:
   ```bash
   git rev-parse --abbrev-ref HEAD
   ```

3. If not already on the default branch, switch:
   ```bash
   git checkout "$BASE"
   ```

4. Pull latest:
   ```bash
   git pull --ff-only origin "$BASE"
   ```
   If `--ff-only` fails (the local default branch has diverged), stop:
   > "Cannot fast-forward `<default branch>` — local commits exist. Resolve manually before continuing."

Continue to step 3 with the default branch checked out and current.

## step 3 — identify subsystem

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
- **Missing** → stop: "`<subsystem>` has no HLD section. Run `/design-docs` to add it before starting."

## step 5 — check LLD existence

Use the exact filename found in step 3 rather than a glob. For subsystems the HLD marks *scaffold only*, skip this step.

```bash
find docs/specs -iname "<exact-LLD-filename>"
```

- **Found** → continue
- **Missing** → stop: "`docs/specs/<exact-LLD-filename>` does not exist. Run `/design-docs` to write it first. Do not write code without an LLD."

## step 6 — check EARS specs

```bash
find docs/specs -iname "EARS-<subsystem>.md"
```

If the spec file exists, search for keywords from the issue title:
```bash
grep -i "<keyword>" docs/specs/EARS-<subsystem>.md
```

If the issue names spec IDs, look each one up directly across all `docs/specs/EARS-*.md` files, and also check which already have tagged tests (`git grep -n '@spec <ID>' -- ':!docs'`).

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
  - **no** → stop: "Refine or add EARS specs in `docs/specs/EARS-<subsystem>.md`, then re-run `/start-task`."
- **Spec file exists, no match** → stop: "No EARS spec for this behaviour. Add one to `docs/specs/EARS-<subsystem>.md` before writing the test."
- **Spec file missing** → stop: "Create `docs/specs/EARS-<subsystem>.md` and write the EARS spec first."

## step 7 — suggest branch name

```
feature-<N>/<3-5-word-slug>   # new functionality
fix-<N>/<3-5-word-slug>        # bug fixes
spike-<N>/<3-5-word-slug>      # research / investigation
docs-<N>/<3-5-word-slug>       # documentation only
```

## step 8 — output the readiness report

```
## Ready to start: #<N> — <issue title>

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
<only when AGENTS.md *Testing* defines test tiers or file-level test tags — omit the section otherwise>
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

If HLD, LLD, or EARS specs are missing: always output "Stop". Never suggest starting to code without HLD, LLD, and EARS specs. On a Stop, leave the step 2 worktree in place and name its path — the `/design-docs` work for the missing artifacts happens there.

## step 9 — branch setup (chain complete only)

Only run this step if step 8 ended with "Chain complete."

Ask: "Create branch `<branch-name>` from the latest default branch and switch to it? (yes / no, or provide a different name)"

If the developer says **yes** (or provides an alternative name):

1. Create and switch to the feature branch (step 2 already put you on the latest default branch — in the worktree, or in the primary checkout in main-worktree mode):
   ```bash
   git checkout -b <branch-name>
   ```

2. In a worktree, git-ignored files are absent: installed dependencies and any generated code. Run the setup `AGENTS.md` describes (dependency install, a *Code generation* section, or similar) there before the first quality gate. If `AGENTS.md` describes none, there is nothing to run.

3. Confirm:
   > "On `<branch-name>` at `<short-sha>` in `<worktree path, or 'the primary checkout'>`. Ready to code."

If the developer says **no**, output:
> "When ready: `git checkout -b <branch-name>` in `<worktree path>`" — or, in main-worktree mode, "`git checkout <default branch> && git pull --ff-only origin <default branch> && git checkout -b <branch-name>`".
