---
name: pre-merge
description: "The last step before merging a pull request: classifies every review item, blocks on anything still fixable or unanswered, rebases onto the latest default branch, keeps EARS IDs unique, runs the gates and the project's pre-merge checks, rebuilds the history as docs then code, files follow-up issues, replies to threads, and merges after asking. Runs only on the developer's explicit OK for that PR, given here or relayed quoting their words ('/pre-merge [PR]', 'merge PR 12'), never because a PR looks ready. Not for fixing findings (/fix-pr-findings) or reviewing (/review-pr). Generic copy: if a project skill named `pre-merge` is also listed, use that one instead."
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/../_shared/scripts/review-threads.sh *)
  - Bash(${CLAUDE_SKILL_DIR}/../_shared/scripts/spec-ids.sh *)
  - Bash(${CLAUDE_SKILL_DIR}/scripts/rebuild.sh *)
  - Bash(${CLAUDE_SKILL_DIR}/scripts/ci-run.sh *)
  - Bash(${CLAUDE_SKILL_DIR}/../_shared/scripts/worktree.sh *)
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

Phase 5 still asks before merging.

No review item is optional: each one ends fixed in this PR or tracked as an issue. Treat review threads from any source (another AI model, the developer, `/review-pr`) alike.

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
| wrapper | AGENTS.md build section: the prefix the toolchain runs through (a version manager's exec command, for example), or none. Run the gates, and each tool the wrapper provides (the tools its config file lists), through it; pass it to this skill's scripts as `--wrap '<wrapper>'` (leave `--wrap` out when it is none); run every other command bare, so it matches `allowed-tools` |
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

`<N>` below is the PR number and `origin/<base>` the remote default branch
(never the local one, which may be stale or checked out elsewhere); write
each in literally. `[#<issue>]` in a commit subject is the issue number, as
`/commit` writes it. Each script in `scripts/` prints its usage when run
with a wrong argument.

## input

`$ARGUMENTS`: optional PR number. If omitted, find the current branch's PR:

```bash
gh pr list --head "$(git branch --show-current)" --json number,title,url --limit 1
```

Show its number, title and URL and ask whether to proceed; wait for the
answer. If there is none, ask for a PR number.

## phase 1 — classify review items

1. Fetch conversation comments and review bodies (GitHub tracks no
   resolution for these), then the unresolved review threads:
   ```bash
   gh api repos/{owner}/{repo}/issues/<N>/comments --paginate
   gh api repos/{owner}/{repo}/pulls/<N>/reviews --paginate
   ${CLAUDE_SKILL_DIR}/../_shared/scripts/review-threads.sh --wrap '<wrapper>' <N>
   ```

2. Collect every review item: each unresolved thread, plus each finding in a review or conversation body that has no thread (*Outside the diff* findings, follow-ups or suggestions listed in prose). Give each a severity (Critical / High / Medium / Low) if the reviewer did not, then classify it:

   | Class | Signals | Meaning |
   |---|---|---|
   | `ADDRESSED` | Code changed since the comment, or a pipeline reply exists ([../_shared/review-replies.md](../_shared/review-replies.md)), unless the latest one starts `Reopened:`, `Not tracked:` or `Not fixed:` | Can be closed |
   | `QUESTION` | Asks for clarification without prescribing a change, and has no answer yet | Needs an answer before merge |
   | `FIX HERE` | Any unaddressed finding, at any severity, that can be fixed on this branch — the default | Must be fixed before merge |
   | `FOLLOW-UP` | Unaddressed, and fixing it here is blocked by a stated reason: a product or design decision not yet made, another subsystem or open issue (name it), or a change too big for this PR (say why) | Becomes a tracked issue before merge |

   Wording such as "nit", "could", "consider" or "nice to have", or a Low severity, does not move an item out of `FIX HERE`; only a stated reason does, and a reviewer's "follow-up" label counts only when its reason holds.

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

   QUESTION (needs an answer)
   | Item | File | Summary | Suggested answer |
   ...

   ADDRESSED (no action needed)
   | Item | File | Summary |
   ...
   ```

4. **If any `FIX HERE` item remains, stop here.** Report them and tell the developer to fix them first (`/fix-pr-findings`), then re-run `/pre-merge`. Do not reply to threads or create issues: phase 2 replaces every SHA, so a reply now would cite a commit that will not survive.

   **If any `QUESTION` remains, stop too**, with a suggested answer for each. The developer answers on the PR, or tells you the answers to post (phase 3 posts them); then re-run.

5. **If `FOLLOW-UP` items remain**, ask:

   > FOLLOW-UP items above will each become a GitHub issue before merge. Reply `ok` to create them all, or name any item to move to FIX HERE instead (e.g. `fix 2`).

   Wait for the answer; if an item moves to `FIX HERE`, stop as in step 4.

## phase 1a — rebase onto the latest default branch and check identifiers

Never skipped because the branch "looks current": everything after this
runs on the code that will reach the default branch.

1. Stop if the working tree is not clean (`git status --short`). Never stash
   or discard the changes; report them and let the developer decide. Stop
   too unless `gh pr view <N> --json headRefName,headRefOid` names the
   current branch and `HEAD`: otherwise this is not PR #<N>'s checkout, or
   it and the PR have each other's unseen commits.

2. Note the current commit as `<pre-rebase-sha>` (`git rev-parse HEAD`),
   then rebase:
   ```bash
   git fetch origin --tags   # --tags: a version bump may read release tags
   git rebase origin/<base>
   ```

   **Conflicts.** Resolve one yourself only when both sides plainly survive
   (two rows appended to one table, two list entries, adjacent sections):
   keep both. When the sides state different intent for the same thing,
   stop, show both and ask. Apply each loaded asset's *After rebase*
   conflict rules on top. Never `git rebase --skip`; if the rebase can't be
   finished, `git rebase --abort` and report.

   **Exception — the version.** When the *pre-merge checks* fact includes a
   version bump, a conflict on the lines or files it writes is never a
   question: take the default branch's side (phase 1b sets the version).

3. Bring the worktree up to date with what the rebase brought in
   (`git diff --name-only <pre-rebase-sha> HEAD`). Run every *setup* step
   that writes git-ignored output (code generation, localization, dependency
   installs). A loaded stack asset's *After rebase* triggers may skip a step
   only when they show the rebase touched none of its inputs; a step no
   trigger covers always runs. Then run the checks in each loaded asset's
   *After rebase* section.

4. **Check that no EARS spec ID is defined twice.** Two branches that each
   took "the next free number" collide here, often without a merge conflict:
   ```bash
   ${CLAUDE_SKILL_DIR}/../_shared/scripts/spec-ids.sh --wrap '<wrapper>' dupes
   ```
   It prints each ID defined more than once, in either the table or the
   `ID: When …` form. Exit 3 means it found no ID at all: if the project has
   EARS specs, their format is one the script doesn't read, so stop and say
   so rather than pass the check.

   For each ID printed, the default branch keeps it. Renumber this branch's
   spec to the next free number in its namespace (never reuse a gap),
   everywhere it appears: the EARS file, every `@spec` tag
   (`git grep -n '@spec <ID>'`) and any doc that cites it. Commit, run the
   check until it prints nothing, and list every renumbered ID in the phase 5
   summary and the PR description.

   Check against the default branch only, never other open PRs: whichever
   colliding branch merges second renumbers. Then run each loaded asset's
   *Unique identifiers* section the same way.

5. Run the *gates* on the rebased branch, in order. Skip them, saying so in
   one line, only when every changed path (`git diff --name-only
   origin/<base>...HEAD`) is Markdown or under `docs/` and none is a build
   input by the *build-input docs* fact. A failure stops the merge: fix it
   on the branch, commit, and re-run this phase from step 2's rebase,
   keeping the `<pre-rebase-sha>` already noted (still the PR's head, which
   phase 2's push leases against).

Do not push yet: phase 2 pushes the rebased branch.

## phase 1b — project pre-merge checks

If the *pre-merge checks* fact is none, say `Pre-merge checks: none recorded
in AGENTS.md` and go on. Otherwise read
[references/pre-merge-checks.md](references/pre-merge-checks.md) and run
every check the fact lists, as it describes: conditional checks, local
suites and their fixtures, checks the developer runs by hand, the version
bump, and the CI-equivalent run (started at the end of phase 2).

## phase 2 — rebuild the branch's commits and push

This runs before any reply is posted, so replies cite only surviving SHAs.

A branch merges as **documentation first, implementation second**, never one
squashed commit where both exist. List what goes in:

```bash
git log origin/<base>..HEAD --format="%h %s%n%n%b"
git diff --name-only origin/<base>..HEAD
```

The **documentation** bucket takes everything under `docs/`, plus whatever a
loaded asset's *Rebuild* section assigns to it (typically a design token or
localization key a doc introduces outside `docs/`), minus what a *Rebuild*
section sends to the implementation bucket. The **implementation** bucket
takes everything else.

If the branch already has that shape (one docs commit then one
implementation commit, or just the one its buckets call for), skip the
rebuild and push as below.

Otherwise compose one message per non-empty bucket, in the format of
[../_shared/git-conventions.md](../_shared/git-conventions.md): type `docs` for the docs commit (its subject says what the specs now
say) and `fix`, `feat` or `chore` for the implementation commit (what the
code now does). Synthesise the bullets across the commits folded in, grouped
by concern; put `@spec` IDs on the implementation commit, each renumbered
identifier in its own bullet, and apply any message rule in a loaded asset's
*Rebuild* section.

Invoking `/pre-merge` approves the wording; show each message in the
report, and reword before merging if the developer asks. Rebuild in one
call, with the messages in `mktemp` files so their backticks stay literal
(drop a `--docs-msg` or `--impl-msg` whose bucket is empty, and add
`--to-docs <path>` / `--to-impl <path>` for each *Rebuild* assignment):

```bash
docs=$(mktemp); impl=$(mktemp)
cat > "$docs" <<'MSG_EOF'
<docs message>
MSG_EOF
cat > "$impl" <<'MSG_EOF'
<implementation message>
MSG_EOF
${CLAUDE_SKILL_DIR}/scripts/rebuild.sh --wrap '<wrapper>' <base> --docs-msg "$docs" --impl-msg "$impl"
rm -f "$docs" "$impl"
```

It resets onto `origin/<base>`, commits each non-empty bucket (only files
the branch changed, never untracked ones), and checks the content is
byte-for-byte unchanged. It prints `pre-rebuild=<sha>`; if it then exits
non-zero, first run the restore command it printed, then stop (nothing was
pushed).

Then push:

```bash
git push --force-with-lease=<head branch>:<pre-rebase-sha>
```

Note the pushed `HEAD` as `<pushed-sha>`. If the push fails, the remote has
commits this checkout lacks: stop and report; never force past it without
the developer's say. Then start phase 1b's CI-equivalent run, if the fact
lists one and the reference doesn't skip it, in the background where the
shell limits long commands:

```bash
${CLAUDE_SKILL_DIR}/scripts/ci-run.sh --wrap '<wrapper>' <workflow file>
```

and judge its conclusion as the reference says.

Last, before any reply: if the default branch has moved (`git fetch
origin`, then `git merge-base --is-ancestor origin/<base> HEAD` fails), go
back to phase 1a: the ID checks and a version bump hold only against the
default branch they ran on.

## phase 3 — reply to addressed threads

For each `ADDRESSED` item fixed on this branch, and each `QUESTION` the
developer gave an answer for (an item whose latest reply is `Tracked in`,
`Captured as` or `Left as-is:` keeps it):

- **Find the commit that carries the fix** by asking git, not guessing from
  the path (files a *Rebuild* section sends to the docs commit ride with it):
  `git log origin/<base>..HEAD --oneline -- <path from the thread>`.
- **Reply** with that commit, unless a person already answered the thread
  in their own words: their answer stands. A pipeline reply (`Addressed in
  <sha>` from `/fix-pr-findings`) is not such an answer: its SHA was
  replaced, so post the surviving one.
  `Addressed in <short-sha> — <description>.`, posted as
  [../_shared/review-replies.md](../_shared/review-replies.md) says. A `QUESTION` gets the developer's answer instead. One sentence at most.

## phase 4 — create issues for FOLLOW-UP items

For every `FOLLOW-UP` item the developer confirmed in phase 1:

1. Read the referenced code for context.
2. Check for duplicates: `gh issue list --search "<keyword>" --state all --json number,title,state --limit 10`. If an open issue already covers it, reply on the thread (or in a PR comment) with `Tracked in #<issue> — <reason it can't be fixed here>.` instead of creating one.
3. Pick a label that exists (`gh label list`): `design` for a missing spec, LLD gap or Arrow of Intent item; `feature`, `bug`, `spike` or `documentation` by what it is. Never create a label or a milestone: use the closest existing label, or none. Apply each loaded asset's *Follow-up issues* section. If the *milestones* fact is set, pick the milestone its rule gives, without asking; otherwise set none.
4. Write the body from [assets/issue-body-template.md](assets/issue-body-template.md) and create the issue, all in one call (drop `--milestone` when there is none):
   ```bash
   body=$(mktemp)
   cat > "$body" <<'ISSUE_BODY_EOF'
   <the filled-in template>
   ISSUE_BODY_EOF
   gh issue create --title "<title>" --label "<label>" --milestone "<milestone>" --body-file "$body"
   rm -f "$body"
   ```
5. If the *project board* fact is set: `gh project item-add <number> --owner <owner> --url <issue-url>`.
6. Reply on the thread, or in a PR comment for an item with no thread: `Captured as #<issue> — <reason it can't be fixed here>.`

## phase 5 — merge

If the default branch has moved again since phase 2 (the same check), stop
and report: re-run `/pre-merge`. Otherwise print:

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

Never merge while a gate or a pre-merge check is failing, or, when the fact
lists a CI-equivalent run, without a `success` on the head commit unless
the reference skipped the run. Then ask:

> Rebase and Merge PR #<N> into `<base>` now? (yes / no)

On **yes**: `gh pr merge <N> --rebase --match-head-commit <pushed-sha>`.
Then, when this ran in a linked worktree, remove it and its branch:

```bash
${CLAUDE_SKILL_DIR}/../_shared/scripts/worktree.sh --wrap '<wrapper>' remove-merged <N> <base>
```

It removes nothing unless the PR shows `MERGED` and this is a linked
worktree, and stops if git refuses (uncommitted changes). Apply each loaded
asset's *Worktree cleanup* section.

On **no**: "When ready: `gh pr merge <N> --rebase --match-head-commit <pushed-sha>`".

No reply or issue body carries AI attribution.
