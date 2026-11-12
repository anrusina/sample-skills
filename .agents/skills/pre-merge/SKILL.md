---
name: pre-merge
description: "Pre-merge PR cleanup: classify every review item, block on anything fixable here, rebase onto the latest default branch, check EARS spec IDs are unique, run the project's pre-merge checks, track follow-ups as issues, reply to addressed threads. Trigger: /pre-merge <N>, only on the developer's explicit OK for that PR — never because a PR looks ready. Generic template: a project's own `pre-merge` skill takes precedence."
---

## step 0 — explicit OK check

Run this skill only on one of these:

- the developer's own message in this session asks for `/pre-merge` (or to
  merge) for this PR, or
- a message relays the developer's OK for **this PR number**, quoting the
  developer's words, e.g. *Owner's OK, verbatim: "<their words>"*.

Nothing else counts: not a PR that looks ready, not a session's summary that
the developer agreed, not an OK given for a different PR. Without one, stop:

> "`/pre-merge` needs the developer's explicit OK for PR #<N>. Ask them, or relay their OK quoting their words."

This step replaces a `disable-model-invocation` gate, so that a relayed OK
loads the skill itself rather than a reading of this file. Phase 5 still asks
before merging.

You are a pre-merge assistant for this project. You classify every open review item, block the merge on anything that can still be fixed in this PR, turn the rest into tracked GitHub issues once the developer confirms them, and reply to addressed threads with commit references. No review item is optional: each one ends fixed in this PR or tracked as an issue.

Run this as the final step before merging a PR.

Review threads may come from any source — a second AI model, the developer, or `/review-pr`. Treat all comments equally regardless of author.

Read the project's `AGENTS.md` before phase 1: it names the quality gates
(*Build and test commands*), any extra checks this skill runs before merging
(*Pre-merge checks*), and any project board (*Project board*). If
*Build and test commands* says tools run through a wrapper (for example a
version manager's exec command), prefix every tool command in this skill with
it.

## input

`$ARGUMENTS`: optional PR number. If omitted, resolve it as follows:

1. Check if the current branch already has a PR associated:
   ```bash
   git branch --show-current
   gh pr list --head <current-branch> --json number,title,url --limit 1
   ```
2. If a PR is found, **show the PR number, title, and URL to the developer and ask**:
   > Found PR #N — "<title>". Proceed with this PR?
   Wait for confirmation before continuing. Do not assume yes.
3. If no PR is found, ask the developer for a PR number.

After confirming the PR number, set the values every later phase uses:
```bash
PR=<N>
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null \
  || git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')
```

## phase 1 — classify threads

1. Fetch conversation comments and review bodies (GitHub tracks no
   resolution for these):
   ```bash
   gh api repos/$REPO/issues/$PR/comments --paginate
   gh api repos/$REPO/pulls/$PR/reviews --paginate
   ```

   Fetch unresolved inline review threads — GraphQL, because REST does not
   report resolution:
   ```bash
   OWNER=${REPO%%/*}
   NAME=${REPO#*/}
   gh api graphql --paginate -F owner="$OWNER" -F name="$NAME" -F pr="$PR" -f query='
   query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
     repository(owner: $owner, name: $name) { pullRequest(number: $pr) {
       reviewThreads(first: 100, after: $endCursor) {
         pageInfo { hasNextPage endCursor }
         nodes { id isResolved path line
           comments(first: 50) { nodes { databaseId body url author { login } } } } } } } }' \
     --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
   ```

2. Collect every review item: each unresolved thread, plus each finding in a review or conversation body that has no thread — *Outside the diff* findings, and any item a reviewer listed as a follow-up or suggestion in prose. Give each one a severity (Critical / High / Medium / Low) if the reviewer did not, then classify it:

   | Class | Signals | Meaning |
   |---|---|---|
   | `ADDRESSED` | Code changed since the comment, or an `Addressed in` / `Verified fixed in` reply exists | Can be closed |
   | `QUESTION` | Asks for clarification without prescribing a change | Needs a reply |
   | `FIX HERE` | Any unaddressed finding, at any severity, that can be fixed on this branch — the default | Must be fixed before merge |
   | `FOLLOW-UP` | Unaddressed, and fixing it here is blocked by a stated reason: a product or design decision not yet made, another subsystem or open issue (name it), or a change too big for this PR (say why) | Becomes a tracked issue before merge |

   There is no skip class. Wording such as "nit", "could", "consider" or "nice to have", or a Low severity, does not move an item out of `FIX HERE`; only a stated reason does. When the reviewer marked an item as a follow-up, check the reason holds — if it doesn't, classify it `FIX HERE`.

3. Print the classification, grouped by class, sorted Critical → High → Medium → Low within `FIX HERE` and `FOLLOW-UP`:

   ```
   FIX HERE (must fix before merge)
   | Item | File | Severity | Summary |
   |------|------|----------|---------|
   | #12 comment 456 | src/auth/login_form.ts:44 | Low | Stale doc comment names the old session store |

   FOLLOW-UP (becomes an issue before merge)
   | # | Item | File | Severity | Summary | Reason it can't be fixed here | Suggested issue title |
   |---|------|------|----------|---------|-------------------------------|-----------------------|
   | 1 | review body, outside-diff #2 | src/cart/cart_service.ts:22 | Medium | Cart refetches prices on every quantity change | Needs the price-caching decision tracked in #18 | Decide cart price caching |

   QUESTION (needs a reply)
   | Item | File | Summary |
   ...

   ADDRESSED (no action needed)
   | Item | File | Summary |
   ...
   ```

4. **If any `FIX HERE` item remains — stop here.** Report them and tell the developer to fix them first (`/fix-pr-findings`), then re-run `/pre-merge`. Do not reply to threads or create issues.

5. **If `FOLLOW-UP` items remain**, ask:

   > FOLLOW-UP items above will each become a GitHub issue before merge. Reply `ok` to create them all, or name any item to move to FIX HERE instead (e.g. `fix 2`).

   Every follow-up ends as an issue or a fix — never as a skip. Wait for the developer's response before proceeding to phase 1a; if an item moves to `FIX HERE`, stop as in step 4.

## phase 1a — rebase onto the latest default branch and check EARS spec IDs

Everything after this phase runs on the code that will actually reach the
default branch: the branch as it stands on top of the latest default branch.
This phase is not optional and is never skipped because the branch "looks
current".

1. Stop if the working tree is not clean (`git status --short`). Never stash
   or discard the changes; report them and let the developer decide.

2. Rebase onto the latest default branch:
   ```bash
   git fetch origin --tags   # --tags: a version bump in phase 1b may read release tags
   BASE=origin/${DEFAULT_BRANCH}
   git rebase "$BASE"
   ```
   Use `$BASE` — the remote ref, not the local `${DEFAULT_BRANCH}` — in
   every later phase; a local default branch may be stale or checked out
   elsewhere. If the branch already contains `$BASE`, the rebase is a no-op;
   continue.

   **Conflicts.** Resolve a conflict yourself only when both sides plainly
   survive: two rows appended to the same table, two entries added to the
   same list, adjacent sections. Keep both. When the two sides state
   different intent for the same thing, stop, show both versions, and ask;
   never pick one silently. Do not `git rebase --skip` a commit. If the
   rebase cannot be finished, `git rebase --abort` and report.

   **Exception — the version.** When `AGENTS.md` *Pre-merge checks* includes
   a version bump, a conflict on the version line(s) or file(s) that bump
   writes is never a reason to ask: take the default branch's side and
   continue. Phase 1b sets the version from the default branch's anyway.

3. Regenerate what the rebase may have invalidated. If `AGENTS.md` lists
   code generation or other steps that write git-ignored output (a
   *Code generation* section, or a step in *Build and test commands*), run
   them now: nothing checked before the rebase proves anything about that
   output now. If it lists none, there is nothing to regenerate.

4. **Check that no EARS spec ID is defined twice.** Spec IDs are append-only
   and unique across all of `docs/specs/`; two branches that each took "the
   next free number" collide here, often without a merge conflict. The check
   runs against the default branch as it stands now, never against other
   open PRs: whichever of two colliding branches merges second meets the
   other's ID here and renumbers.

   ```bash
   # prints every ID that some EARS table row defines
   ears_ids() {
     grep -ohE '^\| *(\[DEPRECATED [0-9-]+\] *)?[A-Z][A-Z-]*-[0-9]+[a-z]?' "$@" \
       | grep -oE '[A-Z][A-Z-]*-[0-9]+[a-z]?$'
   }

   # IDs defined more than once after the rebase — must print nothing
   ears_ids docs/specs/EARS-*.md | sort | uniq -d
   ```

   - **It prints an ID.** The default branch took it first, so this branch
     gives it up. Renumber this branch's spec to the next free number in its
     namespace, never the one already on the default branch, and never
     reuse a number left as a gap. Change it everywhere it appears: the EARS
     row, every `@spec` tag in code and tests (`git grep -n '@spec <ID>'`),
     and any other doc that cites it. Commit the renumbering on the branch,
     run the check again until it prints nothing, and list every renumbered
     ID in the phase 5 summary and in the PR description.

5. Run the quality gates on the rebased branch: each gate `AGENTS.md`
   *Build and test commands* lists (format, lint/analyze, test), in order.
   If that section lists none, ask the developer once for the commands, run
   them, and tell them to record them in *Build and test commands*. If every
   changed path (`git diff --name-only "$BASE"...HEAD`) is Markdown or under
   `docs/`, skip the gates and say so in one line: nothing there can break
   the build.

   A failure stops the merge. Fix it on the branch and re-run this phase.

Do not push yet: phase 2 pushes the rebased branch, whether or not it also
rebuilds the commits.

## phase 1b — project pre-merge checks

Some projects run checks only before a merge: slow or local-only test
suites, a CI-equivalent workflow run, a version bump, release notes. They
are recorded in `AGENTS.md` under *Pre-merge checks*. If there is no such
section, or it lists nothing, say `Pre-merge checks: none recorded in
AGENTS.md` and go on to phase 2.

Otherwise run every check it lists, in its order, on the rebased branch.
Each one's result goes in the phase 5 summary.

- **Conditional checks.** A check that applies only when the branch touches
  certain paths (a native build after a toolchain change, say): compare
  against the branch's changes and run it only when one matches.
  ```bash
  git diff --name-only "$BASE"...HEAD
  ```
  For a file where only some lines count (a manifest whose version line
  phase 1b's own bump changes, say), check in the branch diff which lines
  changed. If nothing on the list is touched, say so in one line.

- **Local suites.** Run the command `AGENTS.md` gives. A failure stops the
  merge, as in phase 1a step 5. If a suite reads git-ignored fixtures that
  live only in the primary checkout, link them into this worktree first,
  where `AGENTS.md` says they live:
  ```bash
  MAIN_CHECKOUT=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
  # for each fixture folder AGENTS.md names:
  [ -e "<folder>" ] || [ ! -d "$MAIN_CHECKOUT/<folder>" ] || ln -s "$MAIN_CHECKOUT/<folder>" "<folder>"
  ```
  If the primary checkout lacks a fixture folder, stop and tell the
  developer which one. The merge waits for a run where the fixtures are,
  unless the developer says in chat to merge without them; then record
  `<suite>: not run (no <folder> on this machine)` in the PR description
  and in the phase 5 summary.

- **Checks the developer runs by hand** (a workflow triggered manually, a
  device test): ask the developer whether it has passed on this branch, and
  **stop until they confirm.**

- **Version bump.** Every merge raises the version once, counted from the
  version the default branch holds now — or from the latest release tag's,
  when `AGENTS.md` says releases are tagged and that is higher (a hotfix can
  release a version the default branch never held) — at the level the
  change calls for:

  | Branch | Level | What it means |
  | --- | --- | --- |
  | `feature-*` | `minor` | New functionality that keeps everything before it working |
  | `fix-*`, `docs-*`, `spike-*`, any other | `patch` | A backward-compatible fix or maintenance |
  | Any, when the developer says so | `major` | A change that breaks what came before, or a major release such as 1.0.0 |

  Take the level from the branch name's prefix. Use `major` only when the
  developer asked for it in this run; never infer it. Run the bump command
  `AGENTS.md` gives, counting from `$BASE`, then commit only if it changed
  something:
  ```bash
  LEVEL=patch
  case "$(git rev-parse --abbrev-ref HEAD)" in feature-*) LEVEL=minor ;; esac
  # <the bump command from AGENTS.md, with $LEVEL and $BASE>
  if [ -n "$(git status --porcelain)" ]; then
    git add <the files the bump writes>
    git commit -m "[#N] chore: raise the version to <new version>"
  fi
  ```
  The new version is always the default branch's version (or the higher
  release tag's) raised once, whatever the branch held before. Run again on
  the same default branch, it computes the same version and finds nothing to
  commit; run after the default branch moved, it bumps from the new version.
  A rebase conflict on the version was already settled by phase 1a's
  exception. Phase 2 folds this commit into the implementation commit.

- **Other checks that change files** (release notes, a status table):
  commit them on the branch, so phase 2 sorts them into its buckets.

- **CI-equivalent run.** A workflow that runs the gates on a clean checkout
  must run on the history phase 2 pushes, so start it at the end of phase 2,
  not now:
  1. If every changed path is Markdown, or under `docs/`, `.agents/` or
     `.claude/`, skip it and say so in one line.
  2. Otherwise look for a run on the head commit first (a pull request that
     edits the workflow file may start one by itself):
     ```bash
     HEAD_SHA=$(git rev-parse HEAD)
     BRANCH=$(git branch --show-current)
     gh run list --workflow <workflow file> --commit "$HEAD_SHA" --json databaseId,status,conclusion,event
     ```
     If none is listed, start one and list again (it can take a few seconds
     to appear):
     ```bash
     gh workflow run <workflow file> --ref "$BRANCH"
     ```
  3. Wait for it to finish, in the background where the shell limits long
     commands:
     ```bash
     gh run watch <run-id> --exit-status
     ```
     `--exit-status` also exits non-zero for a cancelled run, so read the
     conclusion with `gh run view <run-id> --json conclusion`.
  4. Only a `success` conclusion lets the merge go on:
     - `success`: go on to phase 3.
     - `cancelled`: a newer run on the same branch may have replaced this
       one, or someone cancelled it by hand. List the runs on the head commit
       again. If a newer run is listed, watch it; if none is, start one and
       watch that. If a run this step started is cancelled too, **stop** and
       ask the developer.
     - Anything else (`failure`, `timed_out`, `startup_failure`,
       `action_required`, …): show the failing step's output, or the
       conclusion when no step failed, and **stop**: the merge waits for a
       passing run. Fix it on the branch and re-run `/pre-merge`.
       ```bash
       gh run view <run-id> --log-failed | tail -60
       ```

## phase 2 — rebuild the branch's commits locally and push

**This runs before any reply is posted** — the rebuild replaces every SHA,
so replies cite only commits that survive it.

A branch merges as **documentation first, implementation second**, never one
squashed commit where both exist — so the history shows intent arriving
before code.

Collect the commits and the changed files, against the `$BASE` phase 1a
rebased onto:
```bash
git log ${BASE}..HEAD --oneline
git log ${BASE}..HEAD --format="%s%n%n%b"
git diff --name-only ${BASE}..HEAD
```

**Sort the changed files into two buckets.**

The **documentation** bucket takes:

- everything under `docs/`
- any **new design-system token or localization key the docs introduce** —
  a token named by an LLD, or a localization key named by a spec, in the
  design-system or localization files `AGENTS.md` *Project structure*
  names. These belong with the intent that named them, not with the code
  that consumes them, so the docs commit stands on its own.

The **implementation** bucket takes everything else: source, tests,
tooling, config, and workflow files such as `.agents/`.

**Then commit according to which buckets are non-empty — never run
`git commit` against an empty index:**

| Buckets | Result |
|---|---|
| Both non-empty | Two commits, docs first, implementation second |
| Documentation only | One docs commit |
| Implementation only | One implementation commit |

If the branch already matches the required shape for its buckets, no rebuild
is needed: push the rebased branch with `git push --force-with-lease` (same
failure rule as below), run phase 1b's CI-equivalent run if there is one, and
go to phase 3.

Compose one message per commit that will exist:

- **Subject:** `[#N] docs: <what the specs now say>` and
  `[#N] fix|feat|chore: <what the code now does>` — max 72 chars each
- **Body:** `Work done:` followed by 1–5 bullets synthesised across the
  commits folded into it. Group by concern, not one bullet per commit.
  Backtick identifiers. Include `@spec` IDs on the implementation commit.
- No AI attribution trailer, unless `AGENTS.md` asks for one.

Do not ask the developer to approve the wording: invoking `/pre-merge` is the
approval, as it is for `/commit`. Use the messages as composed and show each
one in a fenced block in the report, so the developer can see what went in
before answering the merge question in phase 5. If they want different
wording then, reword and force-push before merging.

Rebuild — running only the `git add`/`git commit` pairs whose bucket is
non-empty:

```bash
PRE_REBUILD_SHA=$(git rev-parse HEAD)   # capture BEFORE either reset

git reset --soft "$BASE"           # phase 1a put the branch directly on it
git reset -q                       # unstage, keep the working tree

# documentation bucket, only if non-empty
git add docs/ <any token/localization files the docs introduced>
git commit -m "<docs message>"

# implementation bucket, only if non-empty
git add -A
git commit -m "<implementation message>"
```

Then verify the rebuild changed only the history, never the content:

```bash
git diff --quiet "$PRE_REBUILD_SHA" HEAD && echo "content identical"
```

Do not use `ORIG_HEAD` instead: the second `git reset -q` overwrites it with
the base commit.

If that diff is not empty, stop — the rebuild dropped or altered something.
Re-run the quality gates from phase 1a step 5 on the rebuilt history before
pushing (they ran against the old commits, not these), then:

```bash
git push --force-with-lease
```

If `--force-with-lease` fails (remote has commits not in local), stop and
report — never force without explicit developer confirmation.

Then run phase 1b's CI-equivalent run, if `AGENTS.md` lists one, on the
history just pushed.

Example pair:
```
[#12] docs: spec sign-in error feedback and lockout

Work done:
- Add LLD §4.2 covering invalid-credential feedback and account lockout
- Add AUTH-001/AUTH-002 for the error state and the lockout threshold
- Add `errorFieldColor` to the auth form's token list
```
```
[#12] feat: show sign-in errors and lock out after repeated failures

Work done:
- Show the error and clear the password field on invalid credentials  // @spec AUTH-001
- Lock the account after the configured number of failed attempts  // @spec AUTH-002
- Add `LoginFormTest` covering error display, field reset, and lockout
```

## phase 3 — reply to addressed threads

The branch now carries its final commits, so every SHA cited here survives
the merge.

For each ADDRESSED thread, and each resolved FIX HERE or QUESTION thread:

- **Find the commit that carries the fix** — ask git, don't guess from the
  path (design-system tokens and localization keys ride with the docs commit
  despite living outside `docs/`):
  ```bash
  git log ${BASE}..HEAD --oneline -- <path from the thread>
  ```
- Reply with that commit reference if no human reply already exists:
  ```bash
  gh api repos/$REPO/pulls/$PR/comments/<comment_id>/replies \
    -X POST -f body="Addressed in <short-sha> — <description>."
  ```
- For general PR comments: `gh pr comment $PR --body "Addressed in <sha> — <description>."`
- One sentence max. Never reply to a thread that already has a human reply.

## phase 4 — create issues for FOLLOW-UP items

For every `FOLLOW-UP` item the developer confirmed in phase 1.

For each item:

1. Read the referenced code for context.
2. Check for duplicates: `gh issue list --search "<keyword>" --state open --json number,title --limit 10`. If an open issue already covers it, don't create one — reply on the thread (or in a PR comment) with `Tracked in #<N> — <reason it can't be fixed here>.` and report it.
3. Map to a label that exists in the repository (`gh label list`):

   | Item type | Label |
   |---|---|
   | Missing spec, LLD gap, Arrow of Intent | `design` |
   | New functionality | `feature` |
   | Broken behaviour | `bug` |
   | Research needed | `spike` |
   | Documentation gap | `documentation` |

   Never create a label. If the matching label does not exist, use the
   closest existing one, or none.

4. Write body to `/tmp/gh-issue-body.md` using [assets/issue-body-template.md](assets/issue-body-template.md).

5. ```bash
   gh issue create --title "<title>" --label "<label>" --body-file /tmp/gh-issue-body.md
   ```
   If `AGENTS.md` has a *Project board* section (owner and number), add the
   new issue to it: `gh project item-add <number> --owner <owner> --url <issue-url>`.
   Without that section, skip this silently.
6. Reply on the thread — or, for an item with no thread, in a PR comment: `Captured as #<N> — <reason it can't be fixed here>.`
7. `rm /tmp/gh-issue-body.md`

## phase 5 — rebase and merge

Print a summary:

```
PR #<N> is ready to merge.

Threads replied to:   <count>
Follow-up issues:     <count> (#N, #N — created or already open)
Rebased onto:         <default-branch> at <short-sha>
EARS spec IDs:        no duplicates (<renumbered IDs as old → new, or "none renumbered">)
Quality gates:        <passed | skipped — documentation only>
Pre-merge checks:     <one line per check: name and result (passed, skipped — reason, not run — reason) | none recorded in AGENTS.md>
Version:              <old> → <new> (<level>) | no version bump recorded
```

If the default branch has moved since phase 1a (`git fetch origin`, then
`git merge-base --is-ancestor origin/${DEFAULT_BRANCH} HEAD` fails), go back
to phase 1a rather than merging: the EARS ID check is only valid against the
default branch it ran on, and a version bump against the version it held.

Then ask:

> Rebase and Merge PR #<N> into `<default-branch>` now? (yes / no)

If the developer says **yes**:
```bash
gh pr merge $PR --rebase
```

Then, **if this ran in a linked worktree** (`git rev-parse --git-dir` differs
from `git rev-parse --git-common-dir`), switch it to the latest default
branch and remove it along with its branch:

```bash
gh pr view $PR --json state -q .state   # must print MERGED
BRANCH=$(git branch --show-current)
WORKTREE=$(git rev-parse --show-toplevel)
MAIN_CHECKOUT=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
git fetch origin
git switch --detach origin/${DEFAULT_BRANCH}
git -C "$MAIN_CHECKOUT" worktree remove "$WORKTREE"
git -C "$MAIN_CHECKOUT" branch -D "$BRANCH"
```

Stop and report instead of removing if the state is not `MERGED`, or the
switch refuses (uncommitted changes) or warns about commits left behind.
Detached, because another checkout may hold the default branch; `-D`,
because a rebase merge gives the commits new SHAs so `-d` would refuse;
`git -C`, because git won't remove the worktree you're standing in.

If the developer says **no**, output:
> When ready: `gh pr merge <N> --rebase`

## rules

- Never reply to a thread that already has a human reply.
- Never create an issue without developer confirmation.
- Never merge without explicit developer confirmation. Rebuilding the branch's commits needs none, and neither does their wording: see phase 2.
- Never merge while a quality gate or a pre-merge check `AGENTS.md` lists is failing, and never merge a change beyond docs without a passing CI-equivalent run on the head commit when `AGENTS.md` lists one (anything else — failing, cancelled, still running or missing — stops it): see phases 1a and 1b.
- Always rebase onto the latest default branch and pass the EARS spec ID duplicate check before merging: see phase 1a. The rebase itself needs no confirmation; a conflict between two intents does. Checks run against the default branch only, never against other open PRs.
- Docs-first commit shape and rebuild-before-reply: see phase 2.
- No AI attribution on any reply or issue body.
