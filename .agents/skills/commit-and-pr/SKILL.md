---
name: commit-and-pr
description: "Commit the finished work, push it and open its pull request, by running /commit and then /pr. Use when the work should go up for review in one go: 'commit and open a PR', 'ship this for review', or a coordinator's brief that says to commit the work and open its PR. Not for a commit alone (/commit) or a PR from commits already pushed (/pr). Generic copy: if a project skill named `commit-and-pr` is also listed, use that one instead."
model: haiku
---

Thin wrapper: run `/commit` then `/pr` in sequence.

Run it only when the developer asked for it, or a brief this session was
started with says to run it once the work is done. Finishing a change is not
by itself a reason to open a PR.

## Project facts

<!-- facts:begin -->
This is the generic copy: no project facts are written into it. Work out each
fact below once, at the start of the run, then write its value literally into
every command that needs it. Each Bash call starts a fresh shell, so a variable
set in one call is empty in the next; never carry a value across calls in a
shell variable.

| Fact | How to find it |
|---|---|
| skill names | `/<name>` when the primary checkout (`dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`) holds the skill in `.agents/skills/<name>/` or `.claude/skills/<name>/`; otherwise the form this skill was installed in: `/sample-skills:<name>` from the plugin, `sample-skills-<name>` from a Codex install. Other skills are named in this file in their short form (`/<name>`); write each in the form this rule gives |
<!-- facts:end -->

If `/commit` or `/pr` does not load, read its `SKILL.md` from the folder
beside this skill's own (`${CLAUDE_SKILL_DIR}/../commit/SKILL.md`, or
`../sample-skills-commit/` in a Codex install) and follow it.

## invocation

```
/commit-and-pr [branch-name] [--squash]
```

## steps

1. Run `/commit` (plus `--squash` if it was passed to this skill). `/commit` pushes by default, and asks for nothing unless it hits a blocker.
   - If `branch-name` was provided, pass it to `/commit` as the name for the new branch.

2. After `/commit` completes successfully, run `/pr`.
