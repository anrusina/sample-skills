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

## Project facts

<!-- facts:begin -->
This is the generic copy: no project facts are written into it. Work out each
fact below once, at the start of the run, then write its value literally into
every command that needs it. Each Bash call starts a fresh shell, so a variable
set in one call is empty in the next; never carry a value across calls in a
shell variable.

| Fact | How to find it |
|---|---|
| `<repo>` | `gh repo view --json nameWithOwner -q .nameWithOwner` |
| `<base>` | `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`; if that fails, `git symbolic-ref --short refs/remotes/origin/HEAD \| sed 's\|^origin/\|\|'` |
| wrapper | AGENTS.md build section: the prefix the toolchain runs through (a version manager's exec command, for example), or none. Run the gates, and each tool the wrapper provides (the tools its config file lists), through it; pass it to this skill's scripts as `--wrap '<wrapper>'`; run every other command bare, so it matches `allowed-tools` |
| gates | AGENTS.md build section: the format, lint/analyze and test commands, in order, or the one command that runs them all |
| setup | AGENTS.md *Worktree setup*: the steps a fresh worktree needs (dependencies, code generation), or none |
| build-input docs | AGENTS.md *Project structure*: Markdown the build reads, or none. Whatever AGENTS.md says, Markdown or MDX inside the source tree that the build reads (content collections, MDX pages, a docs site's sources) counts too. A change to any of it runs the gates like code |
| pre-merge checks | AGENTS.md *Pre-merge checks*: the checks run only before a merge (local suites and their fixture folders, checks the developer runs by hand, a CI-equivalent workflow, a version bump with its command and the files it writes, release notes), or none (skip the steps that need it) |
| releases | AGENTS.md *Releases*: whether releases are tagged, and the tag pattern, or none (skip the steps that need it) |
| project board | AGENTS.md *Project board*: the board's owner and number, or none (skip the steps that need it) |
| milestones | AGENTS.md *Milestones*: how a new issue's milestone is chosen, or none (skip the steps that need it) |
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

`<N>` below is the PR number, `<owner>` and `<name>` are the two halves of
`<repo>`, and `origin/<base>` is the remote default branch. Write each in
literally. `[#N]` in a commit subject is the issue number, as `/commit`
writes it.

## input

`$ARGUMENTS`: optional PR number. If omitted, resolve it as follows:

1. Check if the current branch already has a PR associated:
   ```bash
   gh pr list --head "$(git branch --show-current)" --json number,title,url --limit 1
   ```
2. If a PR is found, **show the PR number, title, and URL to the developer and ask**:
   > Found PR #N — "<title>". Proceed with this PR?
   Wait for confirmation before continuing. Do not assume yes.
3. If no PR is found, ask the developer for a PR number.

The confirmed number is `<N>` in every later phase.

## phase 1 — classify threads

1. Fetch conversation comments and review bodies (GitHub tracks no
   resolution for these):
   ```bash
   gh api repos/{owner}/{repo}/issues/<N>/comments --paginate
   gh api repos/{owner}/{repo}/pulls/<N>/reviews --paginate
   ```

   Fetch unresolved inline review threads — GraphQL, because REST does not
   report resolution:
   ```bash
   gh api graphql --paginate -F owner=<owner> -F name=<name> -F pr=<N> -f query='
   query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
     repository(owner: $owner, name: $name) { pullRequest(number: $pr) {
       reviewThreads(first: 100, after: $endCursor) {
         pageInfo { hasNextPage endCursor }
         nodes { id isResolved path line
           comments(first: 50) { nodes { databaseId body url author { login } } } } } } } }' \
     --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
   ```
   (`$owner`, `$name`, `$pr` and `$endCursor` inside the query are GraphQL
   variables, filled by the `-F` flags and `--paginate`, not shell
   variables.)

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

## phase 1a — rebase onto the latest default branch and check identifiers

Everything after this phase runs on the code that will actually reach the
default branch: the branch as it stands on top of the latest default branch.
This phase is not optional and is never skipped because the branch "looks
current".

The *After rebase* section of each loaded asset applies to steps 2 and 3:
its conflict rules while resolving, its re-run triggers and checks once the
rebase has finished.

1. Stop if the working tree is not clean (`git status --short`). Never stash
   or discard the changes; report them and let the developer decide.

2. Rebase onto the latest default branch. First note the branch's current
   commit as `<pre-rebase-sha>`; step 3 compares against it:
   ```bash
   git rev-parse HEAD
   ```
   ```bash
   git fetch origin --tags   # --tags: a version bump in phase 1b may read release tags
   git rebase origin/<base>
   ```
   Use `origin/<base>` — the remote ref, not the local `<base>` — in every
   later phase; a local default branch may be stale or checked out
   elsewhere. If the branch already contains `origin/<base>`, the rebase is
   a no-op; continue.

   **Conflicts.** Resolve a conflict yourself only when both sides plainly
   survive: two rows appended to the same table, two entries added to the
   same list, adjacent sections. Keep both. When the two sides state
   different intent for the same thing, stop, show both versions, and ask;
   never pick one silently. Apply the conflict rules in each loaded asset's
   *After rebase* section on top of these. Do not `git rebase --skip` a
   commit. If the rebase cannot be finished, `git rebase --abort` and report.

   **Exception — the version.** When the *pre-merge checks* fact includes a
   version bump, a conflict on the version line(s) or file(s) that bump
   writes is never a reason to ask: take the default branch's side and
   continue. Phase 1b sets the version from the default branch's anyway.

3. Bring the worktree up to date with what the rebase brought in. List the
   files it changed under the branch:
   ```bash
   git diff --name-only <pre-rebase-sha> HEAD
   ```
   Run the *setup* steps that write git-ignored output (code generation) or
   install dependencies, as the re-run triggers in the stack asset's
   *After rebase* section say for the files listed. With no stack asset
   loaded, run every *setup* step: nothing checked before the rebase proves
   anything about that output now. If *setup* is none and no asset adds a
   step, there is nothing to regenerate. Then run the checks in each loaded
   asset's *After rebase* section.

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

   Then run the *Unique identifiers* section of each loaded asset: other
   registries whose entries must stay unique (code points, for example),
   checked the same way against the default branch only, with the same
   rule that this branch is the one that moves.

5. Run the *gates* on the rebased branch, in order. If every changed path
   (`git diff --name-only origin/<base>...HEAD`) is Markdown or under
   `docs/`, and none lies under a *build-input docs* path, skip the gates
   and say so in one line: nothing there can break the build. Markdown that
   feeds the build is never covered by this skip.

   A failure stops the merge. Fix it on the branch and re-run this phase.

Do not push yet: phase 2 pushes the rebased branch, whether or not it also
rebuilds the commits.

## phase 1b — project pre-merge checks

Some projects run checks only before a merge: slow or local-only test
suites, a CI-equivalent workflow run, a version bump, release notes. They
are the *pre-merge checks* fact. If it is none, say `Pre-merge checks: none
recorded in AGENTS.md` and go on to phase 2.

Otherwise run every check it lists, in its order, on the rebased branch.
Each one's result goes in the phase 5 summary.

- **Conditional checks.** A check that applies only when the branch touches
  certain paths (a native build after a toolchain change, say): compare
  against the branch's changes and run it only when one matches.
  ```bash
  git diff --name-only origin/<base>...HEAD
  ```
  For a file where only some lines count (a manifest whose version line
  phase 1b's own bump changes, say), check in the branch diff which lines
  changed. If nothing on the list is touched, say so in one line.

- **Local suites.** Run the command the fact gives. A failure stops the
  merge, as in phase 1a step 5. If a suite reads git-ignored fixtures that
  live only in the primary checkout, link them into this worktree first,
  where the fact says they live:
  ```bash
  MAIN_CHECKOUT=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
  # one line per fixture folder the fact names:
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
  when the *releases* fact says releases are tagged and that is higher (a
  hotfix can release a version the default branch never held) — at the
  level the change calls for:

  | Branch | Level | What it means |
  | --- | --- | --- |
  | `feature-*` | `minor` | New functionality that keeps everything before it working |
  | `fix-*`, `docs-*`, `spike-*`, any other | `patch` | A backward-compatible fix or maintenance |
  | Any, when the developer says so | `major` | A change that breaks what came before, or a major release such as 1.0.0 |

  Take the level from the branch name's prefix. Use `major` only when the
  developer asked for it in this run (then set `LEVEL=major` below); never
  infer it. Run the bump command the fact gives, counting from
  `origin/<base>`, then commit only if it changed something — all in one
  call:
  ```bash
  LEVEL=patch
  case "$(git rev-parse --abbrev-ref HEAD)" in feature-*) LEVEL=minor ;; esac
  <the bump command from the fact, with "$LEVEL" and origin/<base>>
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
     `.claude/`, and none lies under a *build-input docs* path, skip it and
     say so in one line.
  2. Otherwise look for a run on the head commit first (a pull request that
     edits the workflow file may start one by itself):
     ```bash
     gh run list --workflow <workflow file> --commit "$(git rev-parse HEAD)" --json databaseId,status,conclusion,event
     ```
     If none is listed, start one and list again (it can take a few seconds
     to appear):
     ```bash
     gh workflow run <workflow file> --ref "$(git branch --show-current)"
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

Collect the commits and the changed files, against the `origin/<base>`
phase 1a rebased onto:
```bash
git log origin/<base>..HEAD --oneline
git log origin/<base>..HEAD --format="%s%n%n%b"
git diff --name-only origin/<base>..HEAD
```

**Sort the changed files into two buckets.**

The **documentation** bucket takes:

- everything under `docs/`, except what a loaded asset's *Rebuild* section
  sends to the implementation bucket
- anything a loaded asset's *Rebuild* section assigns to the documentation
  bucket: typically a new entry (a design token, a localization key) that a
  doc introduces in a file outside `docs/`. It belongs with the intent that
  named it, not with the code that consumes it, so the docs commit stands
  on its own.

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
  Put every renumbered identifier (an EARS ID, or one from a loaded asset's
  *Unique identifiers* section) in its own bullet, and apply any message
  rule in a loaded asset's *Rebuild* section.
- No AI attribution trailer, unless `AGENTS.md` asks for one.

Do not ask the developer to approve the wording: invoking `/pre-merge` is the
approval, as it is for `/commit`. Use the messages as composed and show each
one in a fenced block in the report, so the developer can see what went in
before answering the merge question in phase 5. If they want different
wording then, reword and force-push before merging.

Rebuild. First note the current commit as `<pre-rebuild-sha>`, **before
either reset**:
```bash
git rev-parse HEAD
```

Then reset, keeping the working tree:
```bash
git reset --soft origin/<base>     # phase 1a put the branch directly on it
git reset -q                       # unstage, keep the working tree
```

Then commit, running only the `git add`/`git commit` pairs whose bucket is
non-empty:
```bash
# documentation bucket, only if non-empty
git add docs/ <any files a Rebuild section assigns to docs>
git reset -q -- <docs/ files a Rebuild section sends to implementation>   # drop when none
git commit -m "<docs message>"
```
```bash
# implementation bucket, only if non-empty
git add -A
git commit -m "<implementation message>"
```

Then verify the rebuild changed only the history, never the content:

```bash
git diff --quiet <pre-rebuild-sha> HEAD && echo "content identical"
```

Do not use `ORIG_HEAD` instead: the second `git reset -q` overwrites it with
the base commit.

If that diff is not empty, stop — the rebuild dropped or altered something.
Re-run the *gates* from phase 1a step 5 on the rebuilt history before
pushing (they ran against the old commits, not these), then:

```bash
git push --force-with-lease
```

If `--force-with-lease` fails (remote has commits not in local), stop and
report — never force without explicit developer confirmation.

Then run phase 1b's CI-equivalent run, if the *pre-merge checks* fact lists
one, on the history just pushed.

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
  path (files a *Rebuild* section assigned to the docs commit ride with it
  despite living outside `docs/`):
  ```bash
  git log origin/<base>..HEAD --oneline -- <path from the thread>
  ```
- Reply with that commit reference if no human reply already exists:
  ```bash
  gh api repos/{owner}/{repo}/pulls/<N>/comments/<comment_id>/replies \
    -X POST -f body="Addressed in <short-sha> — <description>."
  ```
- For general PR comments: `gh pr comment <N> --body "Addressed in <sha> — <description>."`
- One sentence max. Never reply to a thread that already has a human reply.

## phase 4 — create issues for FOLLOW-UP items

For every `FOLLOW-UP` item the developer confirmed in phase 1.

For each item:

1. Read the referenced code for context.
2. Check for duplicates: `gh issue list --search "<keyword>" --state open --json number,title --limit 10`. If an open issue already covers it, don't create one — reply on the thread (or in a PR comment) with `Tracked in #<issue> — <reason it can't be fixed here>.` and report it.
3. Map to a label that exists in the repository (`gh label list`):

   | Item type | Label |
   |---|---|
   | Missing spec, LLD gap, Arrow of Intent | `design` |
   | New functionality | `feature` |
   | Broken behaviour | `bug` |
   | Research needed | `spike` |
   | Documentation gap | `documentation` |

   Never create a label. If the matching label does not exist, use the
   closest existing one, or none. Apply the *Follow-up issues* section of
   each loaded asset (an extra label, a detail the body must carry).

   If the *milestones* fact is set, pick the milestone its rule gives,
   without asking; never create a milestone. If it is none, set no
   milestone.

4. Write the body from [assets/issue-body-template.md](assets/issue-body-template.md)
   into a file made by `mktemp`, create the issue, and remove the file —
   all in one call, so the path never has to cross calls and the file goes
   even when `gh` fails. Drop `--milestone` when there is none:
   ```bash
   body=$(mktemp)
   cat > "$body" <<'ISSUE_BODY_EOF'
   <the filled-in template>
   ISSUE_BODY_EOF
   gh issue create --title "<title>" --label "<label>" --milestone "<milestone>" --body-file "$body"
   rm -f "$body"
   ```
   Read the issue URL, or the error, from `gh`'s output.

5. If the *project board* fact is set, add the new issue to it:
   `gh project item-add <number> --owner <owner> --url <issue-url>`.
   If it is none, skip this silently.
6. Reply on the thread — or, for an item with no thread, in a PR comment: `Captured as #<issue> — <reason it can't be fixed here>.`

## phase 5 — rebase and merge

Print a summary:

```
PR #<N> is ready to merge.

Threads replied to:   <count>
Follow-up issues:     <count> (#N, #N — created or already open)
Rebased onto:         <base> at <short-sha>
EARS spec IDs:        no duplicates (<renumbered IDs as old → new, or "none renumbered">)
<one row per loaded asset's Summary section>
Quality gates:        <passed | skipped — documentation only>
Pre-merge checks:     <one line per check: name and result (passed, skipped — reason, not run — reason) | none recorded in AGENTS.md>
Version:              <old> → <new> (<level>) | no version bump recorded
```

If the default branch has moved since phase 1a (`git fetch origin`, then
`git merge-base --is-ancestor origin/<base> HEAD` fails), go back to phase
1a rather than merging: the EARS ID check and every *Unique identifiers*
check are only valid against the default branch they ran on, and a version
bump against the version it held.

Then ask:

> Rebase and Merge PR #<N> into `<base>` now? (yes / no)

If the developer says **yes**:
```bash
gh pr merge <N> --rebase
```

Then, **if this ran in a linked worktree** (`git rev-parse --git-dir` differs
from `git rev-parse --git-common-dir`), switch it to the latest default
branch and remove it along with its branch. First confirm the merge:

```bash
gh pr view <N> --json state -q .state   # must print MERGED
```

Then, in one call:

```bash
BRANCH=$(git branch --show-current)
WORKTREE=$(git rev-parse --show-toplevel)
MAIN_CHECKOUT=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
git fetch origin
git switch --detach origin/<base> \
  && git -C "$MAIN_CHECKOUT" worktree remove "$WORKTREE" \
  && git -C "$MAIN_CHECKOUT" branch -D "$BRANCH"
```

Stop and report instead of removing if the state is not `MERGED`, or the
switch refuses (uncommitted changes) or warns about commits left behind.
Detached, because another checkout may hold the default branch; `-D`,
because a rebase merge gives the commits new SHAs so `-d` would refuse;
`git -C`, because git won't remove the worktree you're standing in. Apply
the *Worktree cleanup* section of each loaded asset.

If the developer says **no**, output:
> When ready: `gh pr merge <N> --rebase`

## rules

- Never reply to a thread that already has a human reply.
- Never create an issue without developer confirmation. Never create a label or a milestone.
- Never merge without explicit developer confirmation. Rebuilding the branch's commits needs none, and neither does their wording: see phase 2.
- Never merge while a gate or a pre-merge check is failing, and never merge a change beyond docs without a passing CI-equivalent run on the head commit when the *pre-merge checks* fact lists one (anything else — failing, cancelled, still running or missing — stops it): see phases 1a and 1b.
- Always rebase onto the latest default branch and pass the EARS spec ID duplicate check, and every loaded asset's *Unique identifiers* check, before merging: see phase 1a. The rebase itself needs no confirmation; a conflict between two intents does. Checks run against the default branch only, never against other open PRs.
- Docs-first commit shape and rebuild-before-reply: see phase 2.
- No AI attribution on any reply or issue body.
