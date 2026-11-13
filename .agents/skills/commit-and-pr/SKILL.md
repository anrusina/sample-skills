---
name: commit-and-pr
description: "Commit, push, and open a pull request — delegates to /commit then /pr. Trigger: /commit-and-pr, or the developer or a coordinator's brief asks to commit the finished work and open its PR. Generic template: a project's own `commit-and-pr` skill takes precedence."
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
