# Task session brief

Fill every `<…>` and send the result as the task session's `prompt`.
`<owner/repo>` is `$REPO` and `<base>` is `$BASE`, both found at the start
of the coordinator run (`gh repo view`). Leave the worktree-setup paragraph
as it is: the session reads the setup steps from AGENTS.md itself.

The first line depends on the issue's mode label. For an **auto** issue, keep
it exactly as shown: it is what makes the session run `/start-task`. For a
**curated** issue, replace it with this line, so the owner can discuss the
approach before any work starts:

```text
Do not start yet: set up the worktree as below, then wait for the owner to type /start-task <N> here. Everything below applies once they do.
```

```text
/start-task <N>

Work GitHub issue #<N> (repo `<owner/repo>`, "<issue title>") in this session,
following the `/start-task` skill, through to an open PR. A coordinator
session started you; it relays between you and the owner. <One or two lines
on where this issue sits: its track, what merged before it, anything the
owner already decided about it.>

Skills: if a skill named here does not load when invoked, read
`.agents/skills/<name>/SKILL.md` and follow it exactly. If you can't start
it that way either, say so plainly in one line and stop; the owner will type
the command here.

Worktree: this session already runs in its own worktree, cut from `<base>`.
Use it as `/start-task`'s worktree instead of adding another: `git fetch
origin` and check HEAD is at `origin/<base>`. If it isn't and the worktree is
clean, run `git checkout --detach origin/<base>`; if it isn't clean, say so
and stop. Then run the project's worktree setup from AGENTS.md (e.g. a
*Worktree setup* list), if any. If a setup step trusts or executes a config
file (a tool-version file, an env file) that differs from `origin/<base>`,
ask before running it.

Repo conventions:
- if AGENTS.md (*Build and test commands*) says tools run through a wrapper,
  always run them that way, never the bare tool
- no Co-Authored-By or other AI attribution trailers on commits, unless
  AGENTS.md asks for one
- review fixes are new commits, never amends or rewritten history
- the PR body says `Closes #<N>`

How to work:
- Proceed through docs and code without asking for a go-ahead. Ask only when a
  real question is open (a design decision, a conflict between the issue and
  the docs, missing intent). Branch names are auto-approved.
- When the work is done and no question is open, run `/commit-and-pr`
  yourself. The PR is where the owner reviews the change. Do not review your
  own PR.
- When asked to run `/fix-pr-findings <PR>`, present its triage and stop. The
  owner chooses; the coordinator relays their choice.
- When told a review round left no findings, write a done report here for the
  owner: a few sentences on what was done, the docs and skill files you
  touched, and the manual tests they should ideally run.
- Whenever you create a GitHub issue (with `/issue`, as a follow-up from
  triage, or any other way), name its number in that turn's report. Don't
  start work on it; the owner decides when it is picked up.
- Never run `/pre-merge` and never merge until the owner's explicit OK
  reaches you, either from the owner here or relayed by the coordinator
  quoting the owner's words.

Reports: the coordinator receives your wrap-up recap (if you give one), then
your closing message, the first 400 characters in all, and acts on the signal
at its start. So begin both the recap and the closing message with one of
these lines:
- `Ready for review: PR #<P> at <sha>` once a push leaves the PR ready (after
  `/commit-and-pr` or a round of fixes), with the worktree clean and nothing
  more to push. The coordinator starts the next review round on it.
- `Triage ready: PR #<P>` after presenting `/fix-pr-findings`' triage.
- `Done: PR #<P>` after the done report.
- `Question: <the question in one line>` when blocked.

`<sha>` is the short commit SHA (`git rev-parse --short HEAD`).

Keep the rest short: the owner reads the details here. Add more for the
coordinator only when it reaches beyond this ticket: an issue you created,
or something that affects another ticket in progress or the phase plan
(scope moved, a new dependency).
```
