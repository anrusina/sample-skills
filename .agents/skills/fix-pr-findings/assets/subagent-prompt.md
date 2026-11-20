# Sub-agent prompt template

Substitute all `<...>` placeholders before spawning. The sub-agent sees only
this prompt, not the orchestrator's shell, facts or conversation: write every
value in literally, the agreed fix included.

---

You are fixing a PR review finding.

Repository: <repo>
PR: #<number> on branch <head> → <base>
Finding #<N>: [<Severity>] <Title>
Description: <full description from the review comment>
Agreed fix: <the fix as agreed with the developer: triage's solution for this finding, with any change or decision from the discussion that constrains it; for a partial fix, which half is fixed here>
File(s): <path(s) and line(s)>
Discussion URL: <URL>
Tool wrapper: <the wrapper fact, or "none">
Build-input docs: <the build-input docs fact, or "none">
Field and stack rules: <the *Fix* section of each loaded asset, pasted in, or "none">
Commit skill: <the /commit skill, named as the skill names fact gives>

Run any tool the wrapper provides through the tool wrapper; run git and other
commands bare.

Steps:
1. Read AGENTS.md for project constraints.
2. Read the referenced file(s) to understand the current code.
3. Apply the agreed fix, following the field and stack rules above. Where it and the review comment differ, the agreed fix wins.
4. If the fix changes code (production source or tests), add or update tests tagged with `@spec <SUBSYSTEM-NNN>` (in the language's comment syntax, on the line before the test) covering the happy path and the failure case. Tag only with an EARS spec that exists and states the behaviour; if none does, stop and report back "no spec covers this behaviour" rather than invent an ID. Skip this for a documentation-only fix (every changed file is Markdown or under `docs/`, and none is under a build-input docs path).
5. Stage only the files relevant to this fix, plus anything the field and stack rules say to stage with them, and run the commit skill: it runs the gates, commits what is staged as a new commit and pushes. Name the finding (`PR #<number> <Severity> #<N>`) and the discussion URL in its *Work done*.
6. If the commit skill stops on a gate failure, fix it and run the commit skill again. If it stops for anything else (a rejected push, an Arrow of Intent contradiction), stop and report back what it said.
7. Report back the commit hash and a one-line summary, or the failure and where it stopped.
