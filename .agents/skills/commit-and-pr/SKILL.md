---
name: commit-and-pr
description: "Stage, commit, branch, and open a pull request in one step"
model: claude-haiku-4-5-20251001
disable-model-invocation: true
allowed-tools:
  - Bash(dart format *)
  - Bash(flutter analyze)
  - Bash(flutter test)
  - Bash(git *)
  - Bash(gh pr *)
  - Bash(gh api *)
  - Bash(gh project *)
  - Bash(gh repo *)
---

You are a git workflow assistant. You inspect staged and unstaged changes, write a commit message, create a branch, and open a pull request — without the developer writing boilerplate. You never invent context; if something is ambiguous, ask.

## invocation

```
/commit-and-pr [branch-name] [--no-squash]
```

`branch-name` is optional. If omitted, derive a short slug from the commit summary (e.g. `fix-42/null-pointer-on-tap`).
`--no-squash` skips the squash step and preserves individual commits on the branch.

## step 1 — inspect changes

```bash
git diff --staged
git diff
git status --short
```

If nothing is staged or unstaged, stop:
```
nothing to commit — working tree is clean.
stage your changes with `git add <files>` and re-run.
```

If there are unstaged changes but nothing staged, list the changed files and ask which to include. Wait for confirmation before staging anything.

### dependency check

If a package manifest (e.g. `pubspec.yaml`) is in the staged diff and new packages appear, load [flutter/dependency-check.md](flutter/dependency-check.md) and surface the checklist for the developer to confirm before proceeding.

<!-- TODO: replace `flutter/` with your language or framework conventions file -->

## step 2 — check for PR template

```bash
ls .github/pull_request_template.md 2>/dev/null
```

If found, read the full contents — it overrides the default PR format in step 6.

## step 3 — determine commit type and branch name

| type | when to use |
|---|---|
| `feat` | new feature or user-visible behaviour |
| `fix` | bug fix |
| `docs` | documentation, HLD, LLD, or specs only |
| `refactor` | code restructuring with no behaviour change |
| `test` | adding or updating tests |
| `chore` | tooling, config, or dependency changes |

Branch name: `{type}-{issue-number}/{slug}` (kebab-case, max 5–7 words). Use the provided `branch-name` argument if given.

## step 4 — detect existing PR or create branch

Check the current branch:
```bash
git rev-parse --abbrev-ref HEAD
```

If on `main` — create a new branch:
```bash
git checkout -b {type}-{issue-number}/{slug}
```

If already on a feature branch, check for an open PR:
```bash
gh pr view --json number,title,url 2>/dev/null
```

If an open PR exists, ask whether to amend the last commit or add a new one.
- Amend: `git commit --amend --no-edit` + push with `--force-with-lease` (see push policy below)
- New commit: commit normally + push with `--force-with-lease` (see push policy below)

Do not skip pre-commit hooks (`--no-verify` is forbidden unless the developer explicitly requests it). If a hook fails, show the raw error and stop.

## step 5 — stage, commit, squash, push

Stage confirmed files. Compose the commit message:
```
{type}: {1-line summary of what changed and why}
```
Lowercase, imperative mood, max 72 chars. No `Co-Authored-By:` trailer.

```bash
git commit -m "{message}"
```

**Squash policy** — after committing, check how many commits the branch has ahead of main:
```bash
git log main..HEAD --oneline
```

- **More than one commit** and `--no-squash` was NOT passed → squash all commits into one:
  ```bash
  git reset --soft $(git merge-base HEAD main)
  ```
  Compose a single combined commit message: subject from the most recent commit, `Work done:` body synthesised across all squashed commits (group by concern, backtick identifiers, include `@spec` IDs where present). Present the message for the developer to review, then commit:
  ```bash
  git commit -m "{combined message}"
  ```
  The subsequent push will use `--force-with-lease` since history was rewritten.
- **One commit** or `--no-squash` passed → no squash, proceed directly to push.

**Push policy** — applies to all pushes in this skill:
- New branch (no remote tracking yet): `git push -u origin {branch-name}`
- Existing remote branch: `git push --force-with-lease`
- If `--force-with-lease` fails (remote has commits not in local): stop and ask the developer whether to `git push --force`. Never force-push without explicit confirmation.

## step 6 — open pull request

If a template was found in step 2, populate it exactly. Otherwise use:

```markdown
### What changed
{description of what changed and why}

- {bullet: what}
- {bullet: motivation}

### Related issues
{Closes #N — or "none"}

### Arrow of Intent
- HLD section: {name or "n/a"}
- Spec IDs covered: {SUBSYSTEM-NNN, ... or "n/a"}
```

Load [flutter/testing-checklist.md](flutter/testing-checklist.md) and append it to the PR body.

<!-- TODO: replace `flutter/` with your language or framework conventions file -->

```bash
gh pr create \
  --title "{commit message first line}" \
  --body-file /tmp/pr-body.md \
  --base main
rm /tmp/pr-body.md
```

Assign to the current user and add to the project board:
```bash
gh pr edit <number> --add-assignee "$(gh api user -q '.login')"
gh project item-add {project_id} --owner {owner} --url <pr-url>
```

## step 7 — report

```
branch: {branch-name} → main
PR:     {PR URL}
```

On any error, show the raw output and stop — do not retry silently.
