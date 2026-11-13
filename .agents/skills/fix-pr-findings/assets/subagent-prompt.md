# Sub-agent prompt template

Substitute all `<...>` placeholders before spawning. Values are written in literally: the sub-agent cannot see the orchestrator's shell or facts.

---

You are fixing a PR review finding.

Repository: <repo>
PR: #<number> on branch <head> → <base>
Finding #<N>: [<Severity>] <Title>
Description: <full description from the review comment>
File(s): <path(s) and line(s)>
Discussion URL: <URL>
Tool wrapper: <the wrapper fact, or "none">
Quality gates: <the gates fact, in order>
Format fix: <the format-fix fact, or "none">
Build-input docs: <the build-input docs fact, or "none">
Field and stack rules: <the *Fix* section of each loaded asset, pasted in, or "none">

Run the quality gates, and any tool the wrapper provides, through the tool
wrapper; run git and other commands bare.

Steps:
1. Read AGENTS.md for project constraints.
2. Read the referenced file(s) to understand the current code.
3. Apply the fix described in the finding, following the field and stack rules above.
4. If the fix changes code (production source or tests), add or update tests tagged with `@spec <SUBSYSTEM-NNN>` (in the language's comment syntax, on the line before the test) covering the happy path and the failure case. Skip this for a documentation-only fix (every changed file is Markdown or under `docs/`, and none is under a build-input docs path) — there is nothing to spec-test.
5. If the fix changed code, tests, build configuration or any other build input (build-input docs included), run every quality gate above, in order, and fix any new failures before committing; when only the format gate fails, run the format fix. Skip the gates for a documentation-only fix — those files cannot affect formatting, analysis or tests.
6. Stage only files relevant to this fix, plus anything the field and stack rules say to stage with them.
7. Commit using the format in [commit-format.md](commit-format.md). Always a new commit — never amend or rewrite a commit already pushed.
8. Push the commit with a plain `git push`. The fix is a new commit on top of the branch, so no force is needed. If the push is rejected, stop and report back: "push rejected: the remote branch moved". Never force-push, with or without a lease.
9. Report back the commit hash and a one-line summary, or the failure and where it stopped.
