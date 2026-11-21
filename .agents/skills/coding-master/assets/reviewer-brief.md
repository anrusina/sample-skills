# Reviewer session brief

Fill every `<…>` and send the result as the reviewer session's `prompt`.
Leave only the session's own placeholders as they are: `<sha>`, `<n>`, `<r>`,
`<count by severity>` and `<name>`. `<owner/repo>` and `<base>` are the
`<repo>` and `<base>` facts, written in literally; `<review-pr>` is
`review-pr`'s invocation form from the skill names fact (e.g. `/review-pr` or
`/sample-skills:review-pr`). `<deep>` is ` --deep` when the PR changes
production source code (the source tree AGENTS.md's project-structure section
names; `gh pr diff <P> --name-only` lists the files), and empty otherwise.
Give it nothing from the task session: no
summary of the change, no reasons, no expected findings.

Only when the reviewer starts before the task session has reported
`Ready for review`, put this line first, above the `<review-pr>` line, so
the session waits for the coordinator's go instead of running the command
at once:

```text
Before running <review-pr> below, wait for the coordinator's message "Go: review PR #<P> at <sha>". Do nothing until it arrives.
```

```text
<review-pr> <P> --post<deep>

Review pull request #<P> in `<owner/repo>` with the `<review-pr>` skill and
post the review to GitHub. A coordinator session started you; another session
owns the fixes.

Skills: if `<review-pr>` does not load when invoked, read its SKILL.md from
wherever it is installed: the project's `.agents/skills/review-pr/` or `.claude/skills/review-pr/`, or the
plugin's copy at `<installPath>/.agents/skills/review-pr/`, where
`<installPath>` is the `installPath` that `claude plugin list --json` prints
for `sample-skills`, and follow it exactly. If you
can't start it that way either, say so plainly in one line and stop; the
owner will type the command here.

Rules:
- You never fix anything: no edits, commits or pushes to the PR branch. Post
  findings and thread verdicts only.
- This session runs in its own worktree, cut from a fresh `origin/<base>`.
  Leave it clean and never switch its branch; do all review work in the
  `review-<P>-*` worktree that `<review-pr>` creates under the primary
  checkout's `.claude/worktrees/`.
- If AGENTS.md's build section says tools run through a wrapper, always run
  them that way.
- When asked to re-run, run `<review-pr> <P> --post` again as a fresh review
  of the PR's current head, without `--deep`: the history lenses belong to
  the first round.

The coordinator receives your wrap-up recap (if you give one), then your
closing message, the first 400 characters in all, and acts on the signal at
its start. So begin both the recap and the closing message with
`Review posted: PR #<P> at <sha>, <n> new findings (<count by severity>), <r> earlier threads reopened or still open`, where
<sha> is the short SHA of the head you reviewed, then the review URL.
```
