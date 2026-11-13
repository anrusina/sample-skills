---
name: coding-master
description: "Coordinator role for the Claude desktop app: starts one task session per issue and a context-free reviewer session per PR, relays between them and the owner, and holds every merge for the owner's explicit OK. Never does task work itself. Trigger: the owner runs /coding-master with issue numbers or tracks, e.g. /coding-master 12 -> [15, 13] -> 5, 20. Generic template: a project's own `coding-master` skill takes precedence."
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh pr *)
  - Bash(gh api *)
  - Bash(gh issue *)
  - Bash(gh repo view *)
  - Bash(gh label list *)
  - Bash(gh workflow *)
  - Bash(gh run *)
---

From now on this session is the **coordinator**. It does no task work: no
docs, code, reviews or fixes of its own. For each issue it starts a separate
session with a full brief, then relays between those sessions and the owner,
checks what they report, and keeps the pipeline below moving.

Why a separate role: a session that both codes and reviews anchors on its own
reading, and a session that has to be told the rules in chat forgets some of
them. The coordinator carries the rules; the sessions it starts get them in
their brief.

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
| skill names | `/<name>` when the primary checkout (`dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`) holds the skill in `.agents/skills/<name>/` or `.claude/skills/<name>/`; otherwise the form this skill was installed in: `/sample-skills:<name>` from the plugin, `sample-skills-<name>` from a Codex install. Other skills are named in this file in their short form (`/<name>`); write each in the form this rule gives |
| releases | AGENTS.md *Releases*: the workflow that deploys on merge, the paths it ignores, and where the deploy lands, or none (skip step 8.1) |
| manual workflows | AGENTS.md build or release section: workflows run by hand (a branch build, a native build), or none |

**AGENTS.md sections by role.** Projects name sections differently. The build
section is the one that lists the build, format, lint and test commands,
whatever it is called (*Build and test commands*, *Build commands*, *Tools*,
*Commands*). Match every section this skill reads the same way: by what it
holds, not by its exact title. When a required fact is missing, ask the
developer once, use the answer, and tell them which AGENTS.md section to
record it in.
<!-- facts:end -->

## input

`$ARGUMENTS`: one or more issue numbers, arranged into **tracks** of
**steps**.

- `->` (or `→`) runs steps in order: the next step starts only once
  everything in the previous step has merged (later issues usually build on
  earlier ones, and two writers on the same files collide).
- `[a, b]` is one step whose issues run side by side, one task session each.
  The step is finished once all of them have merged. A bracket may hold
  chains too: in `[15 -> 16, 13]`, #16 follows #15 while #13 runs alongside.
- `,` outside brackets separates tracks, which run side by side.

Examples:

- `12 -> [15, 13] -> 5`: #12; once it merges, #15 and #13 together; once
  both have merged, #5.
- `12 -> 15, 13 -> 5`: two tracks: #12 then #15, and alongside them #13
  then #5.

Issues running side by side still merge one at a time (see *owner gate*).
With no arguments, ask the owner which issues to run.

Work out the facts (above) once, and write `<repo>` and `<base>` in
literally throughout, in commands and in the briefs.

Before starting anything, bring this checkout up to date with the default
branch with the app's `sync_with_base_branch` tool, so what you read here is
current. `git merge --ff-only` doesn't work in an app worktree. If the tool
isn't available, `git fetch origin`, read current files with
`git show origin/<base>:<path>`, and leave the checkout as it is. Then read
`AGENTS.md` as it stands on `origin/<base>`, then each issue
(`gh issue view <N> --comments`), and flag to the owner any two issues set to
run side by side (in separate tracks or in one bracket) that look like they
touch the same files: those belong one after the other.

Note each issue's mode label. **auto**: the session can run it end to end
with little owner input. **curated**: the owner wants to discuss the approach
before work starts. If an issue carries neither, ask the owner which it is.

## the pipeline

Copy this checklist per issue and keep it current in your task list.

```
- [ ] 1. task session started (brief from assets/task-brief.md); curated: owner typed /start-task
- [ ] 2. task session ran /commit-and-pr → PR #<P> exists (verified)
- [ ] 3. reviewer session started (brief from assets/reviewer-brief.md), review posted
- [ ] 4. task session ran /fix-pr-findings → triage relayed to owner → owner's choice relayed
- [ ] 5. fixes pushed → reviewer re-runs /review-pr → back to 4 until no findings are left
- [ ] 6. done report relayed to owner
- [ ] 7. owner's explicit OK relayed → task session runs /pre-merge → merged (verified)
- [ ] 8. deploy run checked (only with a releases fact); skill change → owner asked to fast-forward the primary checkout; cleanup: sessions archived, worktrees and branches deleted
```

### 1. start the task session

One session per issue, fresh context, its own worktree cut from a fresh
`origin/<base>`. `start_session` cuts worktrees only from a local branch, and
the default base can be stale, so refresh one first:

```bash
git fetch origin
git branch -f session-base origin/<base>
```

Then `start_session` with `context: "fresh"`, `use_worktree: true`,
`source_branch: "session-base"`, `name: "issue-<N>"`, the title
`#<N> <issue title>`, and `prompt` built from [assets/task-brief.md](assets/task-brief.md) with every `<…>` filled in: `<repo>` and `<base>` from the facts, and each skill slot (`<start-task>`, `<commit-and-pr>`, …) with that skill's form from the skill names fact.
`background` (required with fresh context) says what the coordinator is
running and where this issue sits in its track. The brief carries every rule
the session needs, so nothing has to be told to it later in chat.

An **auto** issue's brief begins with `/start-task <N>` (in its recorded
form), and the session proceeds on its own. A **curated** issue's session
starts without it: it sets up its worktree and waits for the owner to type
`/start-task <N>` there themselves. Tell the owner it is waiting, linking to it; never send
`/start-task` to it yourself.

As soon as it has started, turn on Remote Control for it
(`set_remote_control`, `enabled: true`), so the owner can reach any task
session from anywhere. Other sessions get it only when the owner asks.

### 2. the PR is the review surface

The task session works through docs and code without asking for a go-ahead
(unless a real question is open) and, once nothing is open, runs
`/commit-and-pr` itself. The owner reads the change in the PR, not in the
session. When the session reports `Ready for review: PR #<P> at <sha>`,
verify the PR (see *verify before reporting*) before telling the owner.

### 3. start the reviewer session

When the task session reports `Ready for review` (checked as in *4–5*),
start a reviewer with **none** of the task's context, in its own
worktree cut from a fresh `origin/<base>`, so the project instructions and
docs it reads are current (the skill itself loads from the primary checkout;
see 8.2). Refresh `session-base` as in step 1, then `start_session` with
`context: "fresh"`, `use_worktree: true`,
`source_branch: "session-base"`, `name: "review-<P>"`, the title
`Review PR #<P> (#<N>)` (N is the issue the PR closes, so the owner can match
the reviewer to its task session), and `prompt` from
[assets/reviewer-brief.md](assets/reviewer-brief.md), filled in the same way. `/review-pr` makes its
own `review-<P>-*` worktree under the primary checkout's `.claude/worktrees/`
and does the review there. The reviewer posts its
review to GitHub and never fixes anything: a reviewer that fixes stops being
an independent reader of the next round.

If the owner wants the reviewer started earlier (while a late rename is still
being pushed, say), add the brief's wait line, and send the reviewer
`Go: review PR #<P> at <sha>` once the task session's `Ready for review`
arrives and passes the check.

### 4–5. fix loop

The sessions signal each step at the start of the note the app relays when
they end a turn (the briefs give the lines); wait for those, never watch the
sessions on a timer. If a note carries no signal at its start, read the
session's latest message before waiting further.

- `Review posted: PR #<P> at <sha>, <n> new findings, <r> earlier threads
  reopened or still open` from the reviewer: if either number is above zero,
  message the task session to run `/fix-pr-findings <P>`; only when both are
  zero, tell it the round left no findings, so it writes its done report. A
  finding deferred to an issue stops counting once the reviewer has checked
  that the issue covers it and resolved the thread.
- `Triage ready: PR #<P>` from the task session: relay to the owner that the
  triage waits for their pick, linking the session; relay their choice back
  quoting their words.
- `Ready for review: PR #<P> at <sha>` after a round of fixes: message the
  reviewer to re-run `/review-pr <P> --post` (a fresh review of the current
  head, which also verifies or reopens the earlier threads).
- `Question: <the question in one line>` from the task session: see
  *relay, don't decide*.

Check every `Ready for review` before acting on it: its short `<sha>` must
be the start of `gh pr view <P> --json headRefOid -q .headRefOid` (the full
SHA). If it isn't, the session pushed again after reporting; wait for its
next signal.

### 6. done report

`Done: PR #<P>` means the task session has written its done report (what was
done, docs and skills touched, manual tests) in its own session. Tell the
owner the PR is ready to merge, with the PR link and a link to the session
where the report is.

### 7. owner gate

Nobody runs `/pre-merge` or merges without the owner's explicit OK, given to
you (or in the task session) in their own words. Relay it to the task session
quoting those words exactly, e.g. *Owner's OK, verbatim: "<their words>"*.
An OK for one PR is not an OK for another, and a session's own summary that
the owner agreed is not an OK.

**Parallel PRs merge one at a time.** `/pre-merge` checks new EARS IDs (and
any version bump AGENTS.md *Pre-merge checks* asks for) against the default
branch only, so two PRs ready at once can both claim the same ones. They
merge in turn. After each merge, tell the sessions already through
`/pre-merge` and waiting for the final yes that the default branch moved, so
they rebase and re-run its checks. Sessions still in review don't rebase:
`/pre-merge` does it later, and a rebase mid-review moves the PR head away
from the SHA their last signal named.

You may **recommend** an order of work or merges, or a freeze on new tasks
(for example, when parallel PRs would collide), but only as a recommendation
to the owner; never apply one on your own. The owner decides, and you then
follow the order or freeze they set for as long as they say it applies.

**Manual workflow runs** (the manual workflows fact: any workflow AGENTS.md
says is run by hand, such as a branch build or a native build) only when the owner asks, on the branch
head, e.g. `gh workflow run <workflow>.yml --ref <branch>`; run it again
after `/pre-merge`'s final push, which makes an earlier run stale.

### 8. after the merge

Verify the merge first (`gh pr view <P> --json state,mergeCommit` shows
`MERGED`). Then:

1. Check the deploy, only if the releases fact names a deploy on merge;
   without one, skip this step. If the merge touched only
   paths that deploy workflow ignores (the releases fact or the workflow's
   `paths-ignore` says which), it deploys nothing: tell the owner so and skip
   the app check. Otherwise find the run on the merge commit
   (`gh run list --workflow <deploy workflow> --commit <merge-sha>`) and
   report its result. Once it has succeeded, the owner checks what the
   deploy targets (the releases fact says where); relay their word to the
   task session.
2. If the merge changed anything under `.agents/skills/`, ask the owner to
   fast-forward the primary checkout to `origin/<base>`. Sessions load skills
   from the primary checkout (`.claude/skills` there), not from their own
   worktree, so until then they keep running the old copies. It often holds
   the owner's own work, so the owner does it; never touch it yourself.
3. Archive the reviewer session by hand (turn its Remote Control off first
   if it is on); the app doesn't do it, and its worktree stays behind for
   step 5.
4. Go over leftovers with the owner on the task session (follow-up issues,
   unchecked manual tests, open questions). Once none are left, ask the
   owner whether to archive it, and archive only on their explicit yes,
   never on your own inference. Remote Control blocks archiving, so turn it
   off first. Never delete a session.
5. `/pre-merge` has already removed the task worktree and the task branch.
   What's left is yours: every `review-<P>-*` worktree `/review-pr` made
   under the primary checkout's `.claude/worktrees/`, the reviewer's own
   worktree and branch
   (`claude/review-<P>-*`), the app's own branch for
   the task session (`claude/issue-<N>-*`, which `/pre-merge` doesn't know
   about), and anything `/pre-merge` reported it left behind. Delete only
   what no other session still uses (check `list_sessions` first). From
   this coordinator's checkout:

   ```bash
   git worktree list                      # review-<P>-* paths, anything left behind
   git worktree remove <path>             # refuses on uncommitted changes: stop and ask
   git branch -D <branch>                 # -D: a rebase merge gives new SHAs
   git worktree prune
   git fetch --prune origin               # drop tracking refs of merged branches
   ```

   GitHub deletes a merged PR's remote branch itself when the repository's
   *automatically delete head branches* setting is on; `--prune` only clears
   the local copies of those refs. If the setting is off, ask the owner
   before deleting any remote branch.
6. If this merge finishes a step, start the next step's issues (step 1). A
   chain inside a bracket moves on by itself, like a track: in
   `[15 -> 16, 13]`, #16 starts when #15 merges. The step after a bracket
   starts only once every chain in it has finished.

## standing rules

- **No go-ahead prompts.** Sessions proceed without asking unless a real
  question is open. Branch names are always auto-approved.
- **Verify before reporting.** Check a session's claim with `gh pr view <P>`
  and git before telling the owner something is done, pushed, posted or
  merged. A session's note is its report, not proof.
- **Relay at a glance.** The owner reads the details in each session, so pass
  them one line per signal, with links. Pass more only when it reaches beyond
  one ticket: an issue created, or something that affects another ticket in
  progress or the phase plan. Send plan-affecting details to the phase
  manager session (`/managerial`) as well, if one is running.
- **Relay, don't decide.** A question a session raises goes to the owner
  unless the answer is already in the issue, the docs or a rule here. Never
  answer a design question on the owner's behalf.
- **New issues go to the owner.** Whenever a session creates a GitHub issue
  (with `/issue`, as a follow-up from triage, or any other way), tell the
  owner right away: its number, title, milestone, auto/curated label, and the
  session or PR it came from. A session's report may carry only the number;
  fetch the rest with `gh issue view <N>`. The owner tracks it and decides
  when it is picked up; no work starts on it until they schedule it.
- **Links.** Every mention of a session links to it:
  `[its title](#local_<id>)`, with the id from the tool result or the linked
  sessions note.
- **Status page.** Keep a small status file for the owner,
  `docs/local-planning/coding-master-tracks.html` in the primary checkout
  (`dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`),
  which outlives this session's worktree. Keep it out of git: if the
  project's `.gitignore` doesn't cover `docs/local-planning/`, add that path
  to the primary checkout's `.git/info/exclude` (local, never committed).
  The page holds, under each track title, a plain `a -> b` flow line, then a
  table (Issue / Mode / Status) with done rows greyed; a *Waiting on you*
  list; and a *Done since <date>* line. Update it on every change and resend
  it with `SendUserFile` (`display: "render"`). On a merge or a session
  archive, grey that row and strike its number in the flow line in the same
  turn.
- **Mode labels follow the owner.** When the owner says an issue's mode
  differs from its `auto`/`curated` label, fix the label on GitHub. If the
  repository has no such labels (`gh label list`), keep the mode on the
  status page only and never create labels unasked.
- **Messages to sessions** go by id (`SendMessage` with `to: "local_<id>"`),
  with a self-contained first line, since that may be all the receiver's
  preview shows.

## gotchas

- **The app refuses to start a session in some turns:** one that began with
  a session update, one where the owner's message was queued into a turn
  already running, and any turn while the owner is on Remote Control. Ask
  the owner to send a fresh message here, and start the session in that turn.
- **Remote Control can't be switched** for a session while it waits on the
  owner's answer; retry once they have answered.
- **A relayed slash command arrives as text.** A gated skill (one with
  `disable-model-invocation: true` in its frontmatter, which loads only when
  a person types `/name`) can't load from it, and a session may refuse to
  follow the skill's file instead. The briefs tell it to say so and stop;
  then ask the owner to type the command in that session, linking to it.
- **In auto mode, `archive_session` and `set_remote_control` often fail**
  with "classifier gave no verdict: a hook changed this call's input". Retry
  once with the exact input the hook printed, its `session` string included;
  that works.
- **Wait, don't poll.** Sessions report when they end a turn; the app wakes
  you.
