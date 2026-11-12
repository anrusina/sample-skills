# Reviewer session brief

Fill every `<…>` and send the result as the reviewer session's `prompt`
(`<owner/repo>` and `<base>` are the `$REPO` and `$BASE` found at the start
of the coordinator run). Give it nothing from the task session: no summary
of the change, no reasons, no expected findings. An independent reader is
the point of this session.

Only when the reviewer starts before the task session has reported
`Ready for review`, put this line first, above the `/review-pr` line. A
prompt whose first line is a slash command runs it at once; this way the
session waits for the coordinator's go, then loads `/review-pr` itself (it is
not gated).

```text
Before running /review-pr below, wait for the coordinator's message "Go: review PR #<P> at <sha>". Do nothing until it arrives.
```

```text
/review-pr <P> --post

Review pull request #<P> in `<owner/repo>` with the `/review-pr` skill and
post the review to GitHub. A coordinator session started you; another session
owns the fixes.

Skills: if `/review-pr` does not load when invoked, read
`.agents/skills/review-pr/SKILL.md` and follow it exactly. If you can't start
it that way either, say so plainly in one line and stop; the owner will type
the command here.

Rules:
- You never fix anything: no edits, commits or pushes to the PR branch. Post
  findings and thread verdicts only.
- This session runs in its own worktree, cut from a fresh `origin/<base>`.
  Leave it clean and never switch its branch; do all review work in the
  `review-<P>` worktree that `/review-pr` creates inside it.
- If AGENTS.md (*Build and test commands*) says tools run through a wrapper,
  always run them that way.
- When asked to re-run, run `/review-pr <P> --post` again as a fresh review of
  the PR's current head.

The coordinator receives your wrap-up recap (if you give one), then your
closing message, the first 400 characters in all, and acts on the signal at
its start. So begin both the recap and the closing message with
`Review posted: PR #<P> at <sha>, <n> new findings (<count by severity>), <r> earlier threads reopened or still open`, where
<sha> is the short SHA of the head you reviewed, then the review URL. Nothing more is needed.
```
