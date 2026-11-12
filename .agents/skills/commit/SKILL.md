---
name: commit
description: "Commit the current task's changes: stages them, runs quality gates, handles branch creation if on the default branch, writes a focused commit message, commits, and pushes — no confirmation prompts, since review happens in the PR. Leaves existing commits alone unless --squash is passed. Trigger: user or model needs to commit changes. Generic template: a project's own `commit` skill takes precedence."
model: claude-haiku-4-5-20251001
allowed-tools:
  - Bash(git *)
  - Bash(gh pr *)
  - Bash(gh api *)
  - Bash(gh repo *)
  - Bash(curl -s https://api.github.com/repos/*)
---

You are a git workflow assistant for this project. You inspect changes, run quality gates, produce a clear commit message, commit, and push — without requiring the developer to write boilerplate.

**Invoking `/commit` is the approval.** The developer reviews changes in the pull request, not in the staging area or in chat. Do not ask them to stage files, confirm the file list, or approve the commit message. Stop only for a real blocker: a failed quality gate, an Arrow of Intent contradiction, a dependency that fails the security policy, or a destructive action (force-push).

**Tool wrapper.** If AGENTS.md *Build and test commands* says the project's tools run through a wrapper (for example a version manager's exec command), prefix every tool command in this skill with it, `gh` and the quality-gate commands included.

## input

`$ARGUMENTS`: a commit hash (analyse that commit only — report and stop), `--squash` to fold the branch's unpushed commits into one (off by default — see step 10), `--no-push` to commit without pushing, or empty for the full workflow. `--push` is accepted and ignored — pushing is the default.

## step 1 — inspect changes

If a commit hash was provided: `git show --stat <hash>` + `git diff <hash>^ <hash>`. Report and stop — no further steps.

Otherwise:
```bash
git status --short
git diff --staged
git diff
```

If nothing is staged or unstaged, stop:
> "nothing to commit — working tree is clean."

If something is already staged, commit exactly what is staged — the developer chose it — and leave unstaged changes alone.

If nothing is staged, stage the changes yourself with `git add <path>...`, naming each path (never `git add -A` or `git add .`). Include every modified or new file that belongs to the work being committed. Leave out, and name in the final report:
- untracked tooling or scratch paths — `.worktrees/`, build output, editor files
- anything that looks like a secret (`.env`, credentials, keys) — check its contents before deciding
- changes that clearly belong to different work than this commit (another issue, another session)

Do not ask which files to include.

## step 2 — branch check

```bash
BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null \
  || git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')
git rev-parse --abbrev-ref HEAD
```

**On the default branch (`$BASE`)** — committing directly to it is not allowed. Suggest a branch:
```
feature-<N>/<3-5-word-slug>   # new functionality
fix-<N>/<3-5-word-slug>        # bug fixes
spike-<N>/<3-5-word-slug>      # research / investigation
docs-<N>/<3-5-word-slug>       # documentation only
```
Every branch must carry a GitHub issue number. If none is determinable from context, ask the developer — this is the one question this step may ask.

Once the issue number is known, create the branch without asking: `git checkout -b <name>` (use the branch name passed in by the caller, if any), then continue.

**On any other branch** — check for an open PR:
```bash
gh pr view --json number,url 2>/dev/null
```
- Open PR found → add a **new** commit (continue to step 3). Reviewed history is never rewritten, so do not ask. Amend only when the invocation explicitly says to amend:
  - amend: run quality gates (step 5). Then check whether the staged diff touches paths covered by steps 6–7:
    ```bash
    git diff --staged --name-only | grep -E '^docs/(design|specs)/'
    git diff --staged | grep '@spec'
    ```
    - Any `docs/design/` or `docs/specs/` files staged → run step 6 (Arrow consistency check).
    - Any `@spec` tags in the staged diff → run step 7 (@spec tag check).
    Then `git commit --amend --no-edit`. Skip steps 8–9, go to step 10.
- No open PR (or command fails) → continue to step 3. No branch suggestion needed.

## step 3 — split check

Do the changes belong to one logical unit?

| Signal | Action |
|---|---|
| Feature code + its tests + its `@spec` tags | Single commit |
| Multiple unrelated features or fixes | Separate commits |
| Formatting-only changes mixed with logic | Separate commits |
| Doc changes (HLD, LLD, specs) | Separate commit from code |

If splitting is needed, identify file groupings and suggest one message per group.

## step 4 — dependency check

Only when a package manifest is in the diff (`package.json`, `pyproject.toml`, `requirements*.txt`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle*`, or whichever manifest the project uses) and new packages have been added to it. The project's dependency policy, AGENTS.md *Security → Dependency policy*, requires the checks below to be **done**, not merely deferred, before the package is committed — do not stage a dependency addition on the strength of the age check alone.

If AGENTS.md has no dependency policy, apply the generic default: the specific version being added was published at least 14 days ago, its source repository shows no unusual recent activity, and the check is recorded next to the dependency.

How to find the publish date and the source repository for each registry, and where to record the check, is in [conventions/dependency-check.md](conventions/dependency-check.md).

1. List each newly added package name and pinned version.
2. Check the publish date of that exact version. Published **less than 14 days ago** (or under the policy's own threshold, if it sets a longer one) → stop. The security policy forbids adding it; report the date. Do not commit.
3. Check the package's source repository for unusual recent commits, new maintainers, or an activity spike. If the repository can't be located, or its history can't be assessed, stop and report that rather than committing anyway.
4. Record the check next to the dependency — e.g. `Checked <today>: published <publish date>, active maintenance, no unusual activity` — as the convention file describes, and stage that edit together with the dependency change.
5. If either check fails, or either can't be completed, stop. Do not commit the dependency change; report what's missing so the developer can complete it.

## step 5 — quality gates

**Documentation-only fast path.** First check what is being committed:
```bash
git diff --cached --name-only; git diff --name-only
```
If **every** changed path is Markdown or under `docs/` (no source file, manifest, lockfile, config, or other build input), the change set is **documentation-only** — skip the gates entirely and continue to step 6. No formatter, linter or test suite can be affected by Markdown, so running them is pure waste. Any non-doc file in the set makes it non-docs-only, so the gates still run whenever code is present; doc consistency stays guarded by step 6 (`/arrow-check`).

Otherwise, run the quality gates listed in AGENTS.md *Build and test commands* (typically format, lint/analyze, test), each in the order listed; if the section names one command that runs them all, run that. If AGENTS.md lists no gates, ask the developer once for the commands, run them, and tell them to record the commands in AGENTS.md *Build and test commands* so later runs don't ask. Never guess the commands.

- If a format gate rewrites files, re-stage the files it changed (`git add <path>...`) before continuing.
- Any lint/analyze finding the gate reports → show full output, stop. If AGENTS.md says warnings or infos block, they block exactly as errors do.
  Default to fixing the code. Do not add a rule exclusion or an inline suppression comment on
  your own initiative — silencing a rule is a decision about the rule itself,
  not a way past this gate. If an exclusion looks genuinely warranted, stop and
  put the case to the developer with the pros and cons of excluding versus
  fixing, then wait for approval.
- Any test failure → show full output, stop.

## step 6 — arrow consistency check

Only when changed files include paths matching `docs/design/*` or `docs/specs/*`:

Run `/arrow-check`. If it reports any **Contradictions** or **Orphans** — stop and surface them. Missing LLDs flagged as reminders do not block.

## step 7 — @spec tag check

Scan changed source and test files for `@spec SUBSYSTEM-NNN` tags, in whatever comment syntax the language uses (`// @spec AUTH-001`, `# @spec AUTH-001`). For each tag found, verify the spec ID exists in `docs/specs/EARS-<subsystem>.md`. Flag any tags pointing to missing specs — do not block.

## step 8 — write commit message

**Subject prefix** — extract issue number from the branch name:
- Pattern `feature-42/...` or `fix-42/...` → prefix `[#42]`
- No recognisable number → omit prefix

**Conventional type** — choose one:

| Type | When |
|---|---|
| `feat` | New functionality |
| `fix` | Bug fix |
| `docs` | Documentation or spec only |
| `chore` | Tooling, config, dependencies |
| `test` | Tests only |
| `refactor` | Refactor without behaviour change |

**Subject:** `[#N] type: imperative mood, ~72 chars, describes *what* changed.`

**Body:** `Work done:` followed by 1–5 bullets. Imperative, backtick identifiers, explain what and why — not how.

```
# Good — issue prefix, conventional type, imperative, @spec tagged
[#12] feat: clear the password field on invalid credentials

Work done:
- Reset `LoginForm.password` when the auth service rejects the credentials  // @spec AUTH-001
- Show the invalid-credentials error inline, next to the form
- Add `LoginFormTest` covering rejected submit and retry  // @spec AUTH-002
```

**Multiple issues** — if step 3 produced separate commits (one per logical unit), each commit carries its own `[#N]` from context (the issue the change belongs to, not just the branch issue). When the branch itself covers multiple issues and a single commit cannot be avoided, list all numbers: `[#12][#13] feat: ...`.

## step 9 — commit

Commit without asking for approval: `git commit -m "<message>"`. No AI attribution trailer (`Co-Authored-By:` or similar) unless AGENTS.md asks for one. Report the short SHA and show the message in a fenced code block, so the developer can see it; they reword it in the PR if needed.

## step 10 — push (squash only when asked)

Determine the push target (`$BASE` from step 2):

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
# Unpushed commits only — if the branch has a remote, diff against it; otherwise diff against the default branch
git rev-parse --verify origin/$BRANCH 2>/dev/null \
  && git log origin/$BRANCH..HEAD --oneline \
  || git log origin/$BASE..HEAD --oneline
```

**Do not squash** unless `--squash` is passed — `/pre-merge` rebuilds the
branch's history at merge time.

**Squash — only when `--squash` is in `$ARGUMENTS`**, and only when there is
more than one unpushed commit:
- Branch has remote tracking: `git reset --soft origin/$BRANCH`
- No remote yet: `git reset --soft $(git merge-base HEAD origin/$BASE)`

Compose a combined message: subject from the most recent commit, `Work done:` synthesised across all squashed commits (group by concern, include `@spec` IDs). Commit it, then show the message as in step 9.

**Push** — push automatically, with no prompt, unless `--no-push` is in `$ARGUMENTS`.
- New branch (no remote tracking): `git push -u origin $BRANCH`
- Existing remote branch, this run did **not** squash: `git push origin $BRANCH` — a normal, non-forced push. A new commit never needs to rewrite what's already on the remote; a rejected push here means the remote moved and must be investigated, not forced past.
- Existing remote branch, this run **did** squash (`--squash`): `git push --force-with-lease origin $BRANCH` — the squash already rewrote local history, so the push must follow it; passing `--squash` is the developer's explicit authorization for that rewrite.
- If the normal push is rejected, or `--force-with-lease` fails (remote has unfetched commits): stop and ask whether to `git push --force`. Never force-push without explicit confirmation — this is the one push-time question the skill still asks, since force-push is a destructive, hard-to-reverse action.
