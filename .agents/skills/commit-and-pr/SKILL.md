---
name: commit-and-pr
description: "Commit, push, and open a pull request — delegates to /commit then /pr. Trigger: /commit-and-pr, or the developer or a coordinator's brief asks to commit the finished work and open its PR. Generic template: a project's own `commit-and-pr` skill takes precedence."
model: claude-haiku-4-5-20251001
---

Thin wrapper: run `/commit` then `/pr` in sequence.

Run it only when the developer asked for it, or a brief this session was
started with says to run it once the work is done. Finishing a change is not
by itself a reason to open a PR.

## invocation

```
/commit-and-pr [branch-name] [--squash]
```

## steps

1. Run `/commit` (plus `--squash` if it was passed to this skill). `/commit` pushes by default, and asks for nothing unless it hits a blocker.
   - If `branch-name` was provided, pass it to `/commit` as the name for the new branch.

2. After `/commit` completes successfully, run `/pr`.
