---
name: commit-and-pr
description: "Stage, commit, push, and open a pull request in one step"
model: claude-haiku-4-5-20251001
disable-model-invocation: true
---

Thin wrapper: run `/commit` then `/pr` in sequence.

## invocation

```
/commit-and-pr [branch-name] [--no-squash]
```

## steps

1. Run `/commit --push` (plus `--no-squash` if it was passed to this skill).
   - If `branch-name` was provided, supply it when `/commit` prompts to name the branch.
   - `--push` skips the "Push to remote?" confirmation — push happens automatically after the commit message is confirmed.

2. After `/commit` completes successfully, run `/pr`.
