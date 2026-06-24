---
name: start-task
description: "Pre-coding checklist — fetch the issue, verify HLD → LLD → EARS spec chain, identify what must be written before any code is touched"
model: claude-sonnet-4-6
disable-model-invocation: true
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

## step 1 — fetch the issue

```bash
OWNER_REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
gh api repos/${OWNER_REPO}/issues/${NUMBER} --jq '{title, body, labels: [.labels[].name], milestone: .milestone.title}'
gh api repos/${OWNER_REPO}/issues/${NUMBER}/comments --jq '[.[].body] | join("\n---\n")'
```

Extract from both the issue body **and all comments**:
- Issue title and body
- Task list items (`- [ ]` lines) — these are the acceptance criteria
- Any content under headers named "Acceptance criteria", "Done when", or "Requirements"
- Milestone title (if any)
- Comments may contain additional requirements, edge cases, or clarifications added after the issue was written — treat them as part of the acceptance criteria

## step 2 — identify subsystem

Map the issue scope to one or more HLD subsystems by reading `docs/specs/HLD.md`. Match keywords from the issue title and body against subsystem names and responsibilities in the HLD. If the issue matches multiple subsystems, include findings from each in the report. Only ask for clarification if the dominant subsystem is genuinely unclear after reading the HLD.

## step 3 — check HLD coverage

Verify `docs/specs/HLD.md` contains a section for the identified subsystem.

- **Present** → continue
- **Missing** → stop: "`<subsystem>` has no HLD section. Run `/design-docs` to add it before starting."

## step 4 — check LLD existence

```bash
find docs/specs -iname "LLD-<subsystem>.md"
```

- **Found** → continue
- **Missing** → stop: "`docs/specs/LLD-<subsystem>.md` does not exist. Run `/design-docs` to write it first. Do not write code without an LLD."

## step 5 — check EARS specs

```bash
find docs/specs -iname "<subsystem>-specs.md"
```

If the spec file exists, search for keywords from the issue title:
```bash
grep -i "<keyword>" docs/specs/<subsystem>-specs.md
```

Report:
- **Matching spec IDs found** → display the full text of each matching spec, then ask:
  > "Do these specs cover the intended behaviour for this task? (yes / no — refine or add specs first)"
  - **yes** → continue to step 6
  - **no** → stop: "Refine or add EARS specs in `docs/specs/<subsystem>-specs.md`, then re-run `/start-task`."
- **Spec file exists, no match** → stop: "No EARS spec for this behaviour. Add one to `docs/specs/<subsystem>-specs.md` before writing the test."
- **Spec file missing** → note it and continue: "No spec file yet for `<subsystem>`. Tag tests `// @spec TBD` until specs are written."

## step 6 — suggest branch name

```
feature-<N>/<3-5-word-slug>   # new functionality
fix-<N>/<3-5-word-slug>        # bug fixes
spike-<N>/<3-5-word-slug>      # research / investigation
docs-<N>/<3-5-word-slug>       # documentation only
```

## step 7 — output the readiness report

```
## Ready to start: #<N> — <issue title>

### Subsystem: <name>

### Arrow of Intent
- [✓/✗] HLD section: <section name or "missing">
- [✓/✗] LLD: <filename or "missing">
- [✓/~] EARS specs: <IDs, "TBD (no spec file yet)", or "missing">

### Acceptance criteria
<task list items from the issue body, or "None found — confirm scope before starting">

### Suggested branch
<branch-name>

### Next step
<exactly one of the two lines below>
```

End with exactly one of:
- "Chain complete. Write a failing test tagged `// @spec <ID>` (or `// @spec TBD` if specs not yet written), then implement."
- "Stop — <list what is missing>. Run `/design-docs` to create the missing artifacts first."

HLD or LLD missing → always output "Stop". Missing spec file → output "Chain complete" with TBD annotation. Never suggest starting to code without HLD and LLD.

## step 8 — branch setup (chain complete only)

Only run this step if step 7 ended with "Chain complete."

Ask: "Create branch `<branch-name>` from latest main and switch to it? (yes / no, or provide a different name)"

If the developer says **yes** (or provides an alternative name):

1. Check current branch:
   ```bash
   git rev-parse --abbrev-ref HEAD
   ```

2. If not already on `main`, warn: "Currently on `<branch>`. Switching to main first." Then:
   ```bash
   git checkout main
   ```

3. Pull latest main:
   ```bash
   git pull --ff-only origin main
   ```
   If `--ff-only` fails (local main has diverged), stop:
   > "Cannot fast-forward main — local commits exist. Resolve manually before branching."

4. Create and switch to the feature branch:
   ```bash
   git checkout -b <branch-name>
   ```

5. Confirm:
   > "On `<branch-name>` at `<short-sha>`. Ready to code."

If the developer says **no**, output:
> "When ready: `git checkout main && git pull --ff-only origin main && git checkout -b <branch-name>`"
