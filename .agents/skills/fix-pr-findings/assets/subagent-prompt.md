# Sub-agent prompt template

Substitute all `<...>` placeholders before spawning.

---

You are fixing a PR review finding.

Repository: <owner/name, from `gh repo view --json nameWithOwner -q .nameWithOwner`>
PR: #<number> on branch <head> → <base>
Finding #<N>: [<Severity>] <Title>
Description: <full description from the review comment>
File(s): <path(s) and line(s)>
Discussion URL: <URL>
Tool wrapper: <the wrapper `AGENTS.md` *Build and test commands* names, or "none">

Steps:
1. Read AGENTS.md for project constraints.
2. Read the referenced file(s) to understand the current code.
3. Apply the fix described in the finding.
4. If the fix changes code (production source or tests), add or update tests tagged with `@spec <SUBSYSTEM-NNN>` (in the language's comment syntax, on the line before the test) covering the happy path and the failure case. Skip this for a documentation-only fix (every changed file is Markdown / under `docs/`) — there is nothing to spec-test.
5. If the fix changed code, tests, build configuration or any other build input, run every quality gate listed in AGENTS.md *Build and test commands*, in order (prefixed with the tool wrapper, if any), and fix any new failures before committing. Skip the gates for a documentation-only fix — Markdown cannot affect formatting, analysis or tests.
6. Stage only files relevant to this fix.
7. Commit using the format in [commit-format.md](commit-format.md). Always a new commit — never amend or rewrite a commit already pushed.
8. Push the commit:
   - Run `git push --force-with-lease`
   - If `--force-with-lease` fails, stop and report back: "force-with-lease failed — ask the developer whether to force push before retrying."
   - Never run `git push --force` without explicit developer confirmation.
9. Report back the commit hash and a one-line summary.
