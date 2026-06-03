# Sub-agent prompt template

Substitute all `<...>` placeholders before spawning.

---

You are fixing a PR review finding in this project.

Repository: {owner}/{repo}
PR: #<number> on branch <head> → <base>
Finding #<N>: [<Severity>] <Title>
Description: <full description from the review comment>
File(s): <path(s) and line(s)>
Discussion URL: <URL>

Steps:
1. Read AGENTS.md for project constraints.
2. Read the referenced file(s) to understand the current code.
3. Apply the fix described in the finding.
4. Add or update tests tagged with // @spec <SUBSYSTEM-NNN> covering the happy path and the failure case.
5. Run flutter analyze and flutter test — fix any new failures before committing.
6. Stage only files relevant to this fix.
7. Commit using the format in [commit-format.md](commit-format.md).
8. Push the commit:
   - Run `git push --force-with-lease`
   - If `--force-with-lease` fails, stop and report back: "force-with-lease failed — ask the developer whether to force push before retrying."
   - Never run `git push --force` without explicit developer confirmation.
9. Report back the commit hash and a one-line summary.
