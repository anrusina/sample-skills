---
name: commit-and-pr
description: "Commit the finished work, push it and open its pull request, by running /commit and then /pr. Use when the work should go up for review in one go: 'commit and open a PR', 'ship this for review', or a coordinator's brief that says to commit the work and open its PR. Not for a commit alone (/commit) or a PR from commits already pushed (/pr). Generic copy: if a project skill named `commit-and-pr` is also listed, use that one instead."
model: haiku
---

Thin wrapper: run `/commit` then `/pr` in sequence.

Run it only when the developer asked for it, or a brief this session was
started with says to run it once the work is done.

## Project facts

<!-- facts:begin -->
This is the generic copy: work out the facts below as
[../_shared/facts.md](../_shared/facts.md) says. A row marked *shared* takes
its rule from there.

| Fact | How to find it |
|---|---|
| skill names | *shared* |
<!-- facts:end -->

If `/commit` or `/pr` does not load in the form the *skill names* row gives,
run the plugin's (`/sample-skills:commit`, `/sample-skills:pr`); failing that,
read its `SKILL.md` beside this skill's folder (`../commit/`, or
`../sample-skills-commit/` in a Codex install) and follow it.

## invocation

```
/commit-and-pr [branch-name] [--squash]
```

## steps

1. Run `/commit` (plus `--squash` if it was passed to this skill); it also pushes.
   - If `branch-name` was provided, pass it to `/commit` as the name for the new branch.

2. After `/commit` completes successfully, run `/pr`.
