---
name: commit
description: "Commit the current task's changes and push them: stages the task's files, runs the quality gates and /arrow-check, checks new dependencies against the dependency policy, creates a branch when on the default branch, writes a focused message and commits it as a new commit (never amending reviewed history), then pushes. --squash folds the unpushed commits into one. Use whenever changes need committing: 'commit this', 'save this to git', the end of a task, a fix ready to push. To also open a PR, use /commit-and-pr. Generic copy: if a project skill named `commit` is also listed, use that one instead."
model: haiku
allowed-tools:
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git rev-parse *)
  - Bash(git symbolic-ref *)
  - Bash(git merge-base *)
  - Bash(git ls-files *)
  - Bash(git add *)
  - Bash(git checkout -b *)
  - Bash(git reflog *)
  - Bash(git fetch *)
  - Bash(gh pr view *)
  - Bash(gh api *)
  - Bash(gh repo *)
  - Bash(curl -s https://api.github.com/*)
  - Bash(curl -s https://gitlab.com/*)
  - Bash(curl -s https://pub.dev/*)
  - Bash(curl -s https://registry.npmjs.org/*)
  - Bash(curl -s https://pypi.org/*)
---

You inspect changes, run quality gates, write the commit message, commit, and push.

**Invoking `/commit` is the approval.** The developer reviews changes in the pull request. Do not ask them to stage files, confirm the file list, or approve the message. Stop only for a real blocker: a failed quality gate, an Arrow of Intent contradiction, a dependency that fails the security policy, or a push the remote rejects because it holds commits from elsewhere (step 10). `git commit` and `git push` stay out of `allowed-tools` on purpose: their permission prompt, unless the session already allows them, is the developer's yes.

## Project facts

<!-- facts:begin -->
This is the generic copy: work out the facts below as
[../_shared/facts.md](../_shared/facts.md) says. A row marked *shared* takes
its rule from there.

| Fact | How to find it |
|---|---|
| `<base>` | *shared* |
| wrapper | *shared* |
| gates | *shared* |
| format fix | *shared* |
| build-input docs | *shared* |
| dependency policy | AGENTS.md *Dependency policy* (often under *Security*), or the file it points to; or none (the default in [references/dependency-check.md](references/dependency-check.md) applies) |
| skill names | *shared* |
| assets | *shared* |
<!-- facts:end -->

## input

`$ARGUMENTS`: a commit hash (analyse that commit only), `--squash` to fold the branch's unpushed commits into one (step 10), `--no-push` to commit without pushing, or empty for the full workflow.

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

If something is already staged, commit exactly what is staged and leave unstaged changes alone.

If nothing is staged, stage every modified or new file that belongs to this work with `git add <path>...`, naming each path (never `git add -A` or `git add .`). Leave out, and name in the final report:
- untracked tooling or scratch paths — `.worktrees/`, `.claude/worktrees/`, build output, editor files, and the paths in the *Scratch paths* section of each loaded stack asset
- anything that looks like a secret (`.env`, credentials, keys) — check its contents before deciding
- changes that clearly belong to different work (another issue, another session)

Then apply the *Staging* section of each loaded asset.

## step 2 — branch check

```bash
git rev-parse --abbrev-ref HEAD
```

Note the branch name it prints: step 10 writes it in as `<branch>`.

**On the default branch (`<base>`), or detached (it prints `HEAD`)** — never commit here. Suggest a branch named as [../_shared/git-conventions.md](../_shared/git-conventions.md) says. If context gives no issue number, ask the developer (the one question this step may ask).

Then create the branch without asking: `git checkout -b <name>` (the caller's branch name, if one was passed in), and continue.

**On any other branch** — check for an open PR:
```bash
gh pr view --json number,url,state 2>/dev/null
```
- Open PR found (`state` is `OPEN`; a closed or merged one counts as none) → add a **new** commit (continue to step 3), without asking: reviewed history is never rewritten. Amend only when the invocation explicitly says to:
  - amend: run quality gates (step 5). Then check whether the staged diff touches paths covered by steps 6–7:
    ```bash
    git diff --staged --name-only | grep -E '^docs/(design|specs)/'
    git diff --staged | grep '@spec'
    ```
    - Any `docs/design/` or `docs/specs/` files staged → run step 6 (Arrow consistency check).
    - Any `@spec` tags in the staged diff → run step 7 (@spec tag check).
    Then `git commit --amend --no-edit`. Skip steps 8–9, go to step 10.
- No open PR (or command fails) → continue to step 3.

## step 3 — split check

Do the changes belong to one logical unit?

| Signal | Action |
|---|---|
| Feature code + its tests + its `@spec` tags | Single commit |
| Multiple unrelated features or fixes | Separate commits |
| Formatting-only changes mixed with logic | Separate commits |
| Doc changes (HLD, LLD, specs) | Separate commit from code |

Add the rows in the *Split check* section of each loaded asset.

If splitting is needed, identify file groupings and suggest one message per group.

## step 4 — dependency check

Only when a package manifest in the diff (the one the loaded stack asset's *Dependency registry* section names, or whichever the project uses) adds new packages. Every check below must be **done**, not deferred, before the package is committed; the age check alone is not enough. The `dependency policy` fact sets the rules; with none, the generic default applies (14 days, a repository check, the record).

How to find the publish date and the source repository, assess the repository, and record the check is in [references/dependency-check.md](references/dependency-check.md); registry commands, the record's form and any stack policy are in the loaded stack asset's *Dependency registry* section.

1. List each newly added package name and pinned version.
2. Check the publish date of that exact version. Published **less than 14 days ago** (or under the policy's longer threshold) → stop and report the date.
3. Check the package's source repository for unusual recent commits, new maintainers, or an activity spike.
4. Record the check next to the dependency — e.g. `Checked <today>: published <publish date>, active maintenance, no unusual activity` — and stage that edit with the dependency change.
5. If either check fails, or can't be completed (no repository found, history can't be assessed), stop. Do not commit the dependency change; report what's missing.

## step 5 — quality gates

**Documentation-only fast path.** First check what is being committed:
```bash
git diff --cached --name-only; git diff --name-only
```
If **every** changed path is Markdown or under `docs/` (no source file, manifest, lockfile, config, or other build input), and none is a build input by the `build-input docs` fact or the loaded stack asset's *Quality gates* section, the change set is **documentation-only**: skip the gates and continue to step 6.

Otherwise, apply the *Before the gates* section of each loaded asset, then run the gates in order (or the one command that runs them all). Never guess the commands: if AGENTS.md lists none, ask once, as *Project facts* says.

- If a format gate rewrites files, re-stage them (`git add <path>...`). If it only checks and fails, run the format fix (the loaded stack asset's *Quality gates* section names the usual one), re-stage, and run the gates again.
- Any lint/analyze finding → show full output, stop. If AGENTS.md says warnings or infos block, they block exactly as errors do.
  Fix the code. Never add a rule exclusion or inline suppression (the stack asset's *Quality gates* section lists the forms) on your own initiative: that is a decision about the rule, not a way past the gate. If one looks genuinely warranted, stop, put the case for excluding versus fixing to the developer, and wait for approval.
- Any test failure → show full output, stop.
- Apply the *Gate results* section of each loaded asset.

## step 6 — arrow consistency check

Only when changed files include paths matching `docs/design/*` or `docs/specs/*`:

Run `/arrow-check`. If it reports any **Contradictions**, **Orphans** or **Broken** items, stop and surface them. Missing items and Notes do not block.

## step 7 — @spec tag check

Scan changed source and test files for `@spec SUBSYSTEM-NNN` tags, in any comment syntax (`// @spec AUTH-001`, `# @spec AUTH-001`). Verify each ID exists in `docs/specs/EARS-<subsystem>.md`. Flag tags pointing to missing specs; do not block.

## step 8 — write commit message

Write it as [../_shared/git-conventions.md](../_shared/git-conventions.md) says, and apply the *Commit message* section of each loaded asset.

**Multiple issues** — if step 3 split the work, each commit carries the `[#N]` of the issue its change belongs to, not just the branch issue.

## step 9 — commit

Commit with the `mktemp` heredoc in [../_shared/git-conventions.md](../_shared/git-conventions.md). Report the short SHA and show the message in a fenced code block.

## step 10 — push (squash only when asked)

List the unpushed commits (against the remote branch if there is one, else the default branch):

```bash
git rev-parse --verify origin/<branch> 2>/dev/null \
  && git log origin/<branch>..HEAD --oneline \
  || git log origin/<base>..HEAD --oneline
```

**Squash only when `--squash` is in `$ARGUMENTS`** (`/pre-merge` rebuilds the
history at merge time), and only with more than one unpushed commit:
- Branch has remote tracking: `git reset --soft origin/<branch>`
- No remote yet: `git reset --soft "$(git merge-base HEAD origin/<base>)"`

Compose a combined message: subject from the most recent commit, `Work done:` synthesised across all squashed commits (group by concern, include `@spec` IDs). Commit it as in step 9 and show the message.

**Push** without a prompt, unless `--no-push` is in `$ARGUMENTS`.
- New branch (no remote tracking): `git push -u origin <branch>`
- Existing remote branch: `git push origin <branch>` (a new commit or a squash sits on the remote tip).
- If the push is rejected, the remote holds commits this branch no longer has. Without fetching, note the remote tip this checkout last saw: `git rev-parse origin/<branch>` → `<lease-sha>`.
  - **This checkout rewrote them** (a rebase, `/pre-merge`'s rebuild, an amend), so `<lease-sha>` was once this branch's tip here: `git reflog --format=%H <branch> | grep -qx <lease-sha>`. Push without asking: `git push --force-with-lease=<branch>:<lease-sha> origin <branch>`. The lease fails if anything landed on the remote since.
  - **Otherwise, or if that push is rejected too**, the remote has commits from elsewhere (another person or session): `git fetch origin <branch>`, list them with `git log HEAD..origin/<branch> --format='%h %an %ad %s'`, stop, and ask before any force-push.
