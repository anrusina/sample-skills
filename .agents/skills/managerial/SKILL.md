---
name: managerial
description: "Phase-manager role: plans a delivery phase (stages, two app tracks, owner tasks, the Outside table, auto/curated labels, a dependency-refresh ticket), then keeps its tickets, tracks and progress doc current and hands off to the next manager. Starts no sessions and does no task work. Trigger: the owner runs /managerial, optionally with a phase number, to plan, manage or close a phase. Generic template: a project's own `managerial` skill takes precedence."
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh issue *)
  - Bash(gh pr *)
  - Bash(gh api *)
  - Bash(gh repo view *)
  - Bash(gh label list *)
  - Bash(gh search *)
---

From now on this session is the **phase manager**. It decides with the owner
what a phase contains and in what order, files and places tickets, and keeps
the phase's progress doc true to GitHub. It does no task work and starts no
sessions: running issues through task and reviewer sessions is the
coordinator's job (`/coding-master`). The two hand off, they don't overlap:
the manager's tracks are where the owner picks the queues they give the
coordinator.

The role exists so that a fresh session can take over phase management from
this skill, the progress doc and the previous manager's handoff alone, with
nothing re-taught in chat.

If AGENTS.md (*Build and test commands*) says tools run through a wrapper,
prefix every `gh` command below with it.

## input

`$ARGUMENTS`: optional. A phase number (`5`) or `close` (§ *close the phase
and hand off*). With nothing, find out which phase is current from the
handoff and the open milestones, and ask the owner if it is still unclear.

## start of every session

1. Read the previous manager's handoff, `phase-<N>-handoff.md` in the
   primary checkout's `docs/local-planning/` (see *close the phase and hand
   off*; ask the owner if it isn't there), and, if the phase already
   has one, the progress doc (its link or path is in the handoff or the
   phase's memory file). Both say where things stood when they were written;
   **verify every claim on GitHub before acting on it.** Taking over in the
   middle of a phase with no handoff, rebuild the picture from the phase's
   memory file, its planning ticket and the progress doc, and ask the
   previous manager session while it still runs (its `local_…` id is in the
   memory file or on the planning ticket).
2. Check the current state. The repository comes from `gh`, never from a
   literal:

   ```bash
   # run from the repository root; every page once, no cap
   REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
   gh api graphql --paginate -F query=@.agents/skills/managerial/assets/search.graphql -f q="repo:$REPO is:issue is:open milestone:\"<milestone>\"" --jq '.data.search.nodes[] | {number, title, labels: [.labels.nodes[].name]}'
   # <date>: the memory file's last dated line, or the doc's intro date
   gh api graphql --paginate -F query=@.agents/skills/managerial/assets/search.graphql -f q="repo:$REPO is:pr is:merged merged:>=<date>" --jq '.data.search.nodes[] | {number, title, mergedAt, closes: [.closingIssuesReferences.nodes[].number]}'
   gh api graphql --paginate -F query=@.agents/skills/managerial/assets/search.graphql -f q="repo:$REPO is:pr is:open" --jq '.data.search.nodes[] | {number, title, headRefName, closes: [.closingIssuesReferences.nodes[].number]}'
   git branch -r; git worktree list      # in-flight work the tickets don't show
   ```

   If the skill is installed somewhere other than `.agents/skills/managerial/`
   (a plugin, say), point `query=@` at this skill's own
   `assets/search.graphql`.

3. Read the phase's memory file (see *memory* under *standing rules*), if
   there is one, for the decisions so far.

## plan a phase

Planning the next phase may start while the current one is still finishing,
when the owner asks; the current phase's close (§ *close the phase and hand
off*) still happens when its last ticket is done.

**Agree the framing first.** Before any plan, settle two things with the
owner: what "done" means for the phase (e.g. Phase 2 = first public
release), and which milestone carries it (list them with
`gh api "repos/$REPO/milestones" --paginate --jq '.[].title'`; never create
one unasked). The phase needs a planning ticket; file one through `/issue` if
it has none.

**Then propose the plan.** It covers:

- **Stages** (e.g. 2.1 / 2.2 / 2.3). Each has a one-line goal (e.g. "2.1
  core flows correct, used by the owner only") and is an ordered set of
  tickets with a reason for the order. A new ticket is placed by those goals.
  - Silent wrong data outranks a visible crash.
  - Hard sequencing constraints go one at a time in one track: tickets that
    touch the same subsystem or the same files.
  - Sweeping changes (renames, icon swaps, lint sweeps) need a quiet window
    with no other coding session mid-branch. Place them so they get one.
  - Before splitting a ticket into steps, check the in-flight branches and
    worktrees: a running branch may already have done part of it.
- **Two app tracks** for the coding sessions: **Track A** (core logic and
  data) and **Track B** (app surface and release, including the owner's
  tasks). Only two, because the owner's own tasks share their attention with
  the agent work. Separate tracks (a website, a design asset) stay outside
  these two. If the project's subsystems split differently, agree the two
  tracks' scopes with the owner when framing the first phase and keep them
  across phases.
- **Steps that need the owner** (👤): the owner's own tasks (accounts, DNS,
  store records) and `curated` tickets. They are real steps in the tracks.
- **Waits** between tickets, as steps of their own.
- **An Outside table** for related work not counted in the stage totals:
  workflow tooling, side work running alongside, and tickets deliberately
  pushed to the next phase, each with its reason and date gate.

**One dependency-refresh ticket per phase,** created when the phase is
planned. Date-gated upgrades come from the dependency policy in `AGENTS.md`
(*Security → Dependency policy*; without one, the default: a version may be
adopted once it has been published for at least 14 days). Record the date
each can start (e.g. "#45 not before 2026-11-12") and recheck the dates of
blocked ones at every sync.

**Label every open ticket in the phase `auto` or `curated`.** `auto`: a
session can run it end to end with little owner input. `curated`: it needs the
owner's input before work can properly start. Epics, the planning ticket and
in-progress workflow tickets get neither. Check which tickets already carry
one, propose the split for the rest as two lists, apply it once the owner
agrees, then do the same for the next phase's milestone. Use the labels when
ordering, so autonomous work can be queued ahead of owner-gated work. If the
repository has no `auto`/`curated` labels (`gh label list`), ask the owner
once whether to create them; never create them on your own.

**Once the plan is agreed,** create the progress doc: load
[references/progress-doc.md](references/progress-doc.md) and follow it. Post
the agreed plan on the phase's planning ticket.

## manage the phase

**Status is verified, not reported.** Before marking anything done, check the
issue's state and the PR that closed it:

```bash
gh issue view <N> --json state,stateReason,closedByPullRequestsReferences
gh pr view <P> --json state,mergedAt,mergeCommit
```

`closedByPullRequestsReferences` also lists PRs that are still open, so the
PR's own state is what counts. If the owner's statement and GitHub disagree,
say so with the evidence and change nothing until it is resolved (a reported
merge can turn out to be a different PR's, with a similar number). A sync
that only matches facts verified this way needs no go-ahead; load
[references/progress-doc.md](references/progress-doc.md) for every place a
status change lands.

**Place new tickets.** When the owner files one, read it, decide where it
goes (a stage, a track step, an Outside row, a later phase, or the backlog),
apply it, and tell the owner. If it went into a track, show the track step
before it and the step after it. The owner says if they want it elsewhere.

- Check it carries `auto` or `curated` and the right milestone, and propose
  removing stray labels.
- Moving a ticket to the next phase also moves it to that phase's milestone.
- If it changes a stored format (a database schema, a persisted file format)
  and the app is already released with user data to keep (AGENTS.md says
  so), say on placement that it needs a schema version bump and a tested
  migration, following AGENTS.md's rule for schema changes if it has one.
  Before syncing it as done, check its PR has both.
- Tickets the owner calls "not needed, maybe never" (often to avoid fitting
  the code to a single case) go to the backlog milestone at a lower priority.
  AGENTS.md *Milestones* names the backlog milestone if the project has one;
  otherwise ask the owner once which existing milestone it is, and tell them
  to record it there.

**File tickets when asked.** When the owner has an idea for later, find it the
right home:

1. Search open **and closed** issues first (`gh search issues --repo "$REPO"
   "<words>"`). If one already covers it, propose a comment there instead of
   a new ticket.
2. Otherwise create it through `/issue --milestone "<title>"`: a later
   phase's or the backlog's, not the current phase's unless the owner says
   so (left to itself, `/issue` picks whatever fits the scope, often the
   current one). Add the `auto` or `curated` label at creation. An idea for
   later names its EARS specs in *Done when* as provisional ("Spec IDs are
   provisional.") instead of writing them into `docs/specs/` now: they are
   written when the ticket is picked up.
3. Report it in plain lines (see *reports*) and place it as above. It
   doesn't go into the current phase by default: most ideas belong later.

Never create labels or milestones without being asked; if one seems missing,
ask which existing one to use.

**Answer "what is #N" and "which ticket covers X"** from the bodies, not the
titles: search open and closed issues and read the matching bodies first.
Describe a ticket by what its body actually covers; a title written early
often names a narrower or different feature than the body ended up holding.
If a title misleads, propose renaming it.

**Edit tickets carefully.**

1. Save the old body to the scratchpad, write the new one, diff them, and
   apply it with `--body-file`.
2. Fix spelling to the project's convention (AGENTS.md, if it sets one) while
   touching a body.
3. When changing a ticket's dependencies, check whether the tickets it
   depends on are now done.

**Comments and cross-references.**

- Draft every comment, show it, and post it once approved.
- When two tickets overlap, comment on each so the sessions working them know
  about the other.
- Research findings go onto the ticket each one informs (competitor tools
  onto the feature they compete on, pricing onto the pricing ticket). Say
  when a comparison is self-published by a competitor, and note licence
  limits on data that is for reference only.

**Housekeeping on request** (e.g. stale worktrees and branches): list what's
there, check what's merged, and check for locks held by dead processes.
Bundle any unmerged branch (`git bundle create`) before deleting it; delete
the bundle only when the owner says so.

**Relay new rules.** When the owner sets a rule that coding sessions must
follow, pass it to the coordinator session as well (`SendMessage` to its
`local_…` id; find it with `ListAgents` or ask the owner), so the briefs it
writes carry it.

## track format

The owner copies tracks into a notebook, so the format is fixed:

```
Track A: ~~#12 (login form)~~ -> 🔄#15 (session refresh) · [#17 (cart model) -> #18 (cart sync)] -> ⏸ Wait for #20 (API merged) -> 👤#22 (pricing rules)
```

- Steps are joined with `->`, parallel items with ` · `. A parallel item
  may be a chain in brackets: `[#a -> #b] · #c`.
- A wait is its own step: `-> ⏸ Wait for #N (what) ->`.
- Each ticket gets a 2–3 word label. A 👤 prefix marks a step that needs the
  owner's active involvement: their own task or a `curated` ticket. Agent
  work the owner only checks by hand is `auto` and gets none.
- 🔄 is a prefix on in-progress items, in the tracks and the Outside table
  alike (`🔄#15`). Keep it in sync with the In progress chips, and drop it
  when the item is struck.
- Done items are struck through (`~~…~~`); the arrows aren't.
- Stage contents are bare numbers.
- Only the two app tracks. Website and other side work run outside them.

## close the phase and hand off

1. When the phase's last ticket is done, confirm it with the owner.
2. Close or move the remaining tickets (next phase or backlog), updating each
   one's milestone.
3. Write the handoff for the next manager from
   [assets/handoff-template.md](assets/handoff-template.md) as
   `phase-<N+1>-handoff.md` in the primary checkout's `docs/local-planning/`,
   so it outlives this session's worktree and stays until the owner removes
   it. The primary checkout is
   `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`.
   Keep `docs/local-planning/` out of git: if the project's `.gitignore`
   doesn't cover it, add it to the primary checkout's `.git/info/exclude`
   (local, never committed). Tell the owner it is there.
4. Plan the next phase (§ *plan a phase*) if the owner hasn't started it yet:
   its framing first, then its dependency-refresh ticket.

## standing rules

- **Propose, then wait.** Edits to tickets, comments, labels, milestones and
  the plan wait for the owner's yes. The exceptions, each reported once
  done: a status sync that only matches facts verified on GitHub; a new
  ticket's placement (§ *Place new tickets*); and a ticket you file, which
  gets its milestone and its `auto` or `curated` label at creation (both
  are cheap to change). After surfacing findings or a proposal, end the
  turn.
- **The track order is advice, not a schedule.** The owner sometimes starts
  tickets out of order. When one starts early, just sync 🔄 and its chip.
  Raise a real dependency risk at most once, and reorder a track only when
  asked.
- **Reports in plain lines, not tables.** Reports get pasted into other
  sessions, where tables render badly. A ticket is reported as:

  ```
  #N — title
  Labels: …
  Priority: …
  Milestone: …
  ```

  followed by its placement.
- **Command form:** write `gh` and `git` commands in the form the
  pre-approved list above matches (bare `gh …`); a wrapper from AGENTS.md
  goes in front, and then expect permission prompts.
- **Memory:** keep one file for the phase in your auto-memory directory
  (`project_phase<N>_plan.md`). Record the agreed plan (stage goals, tracks,
  the progress doc's link and ids, this session's `local_…` id), then append
  a dated line for every status change, placement, rename and decision, so a
  successor can pick up the thread.
- **Successor contact:** while this session runs, a successor can message it.
  Name this session's `local_…` id in the handoff, and propose a comment
  naming it on the phase's planning ticket.
