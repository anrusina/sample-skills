---
name: fix-pr-findings
description: "Orchestrate fixes for PR review findings via parallel sub-agents"
model: claude-sonnet-4-6
disable-model-invocation: true
---

Orchestrate fixes for GitHub PR review findings in this project. Fetches review comments, presents findings for selection, and spawns sub-agents to apply each fix in isolation with properly formatted commits.

Findings may come from any reviewer — a second AI model, the developer, or `/review-pr`.

## inputs

- A PR comment URL (e.g. `https://github.com/{owner}/{repo}/pull/9#discussion_r188675`)
- A PR number with finding references (e.g. "PR #9, fix criticals" or "PR #9, fix #1 and #3")
- Just "fix PR findings" — uses the open PR for the current branch

## phase 1 — gather findings

1. **Determine the PR.**
   - Extract repo, PR number, and optional discussion ID from the URL if provided.
   - If only a number is given, derive owner/repo from `git remote get-url origin`.
   - If no number given, find the open PR via `gh pr list --head <branch>`.

2. **Fetch review comments:**
   ```bash
   gh pr view <number> --comments --json comments,reviews
   ```
   Extract each finding: number, severity, title, description, file(s) and line(s), discussion URL.

3. **Present findings in a table:**

   ```
   | # | Severity | Title                             | File                         |
   |---|----------|-----------------------------------|------------------------------|
   | 1 | Critical | @spec tag references deleted spec | lib/grid/grid_bloc.dart      |
   | 2 | High     | StreamSubscription not cancelled  | lib/pdf/pdf_viewer.dart      |
   | 3 | Medium   | Missing const constructor         | lib/legend/legend_widget.dart|
   ```

   Ask which findings to fix. Accept: specific numbers ("1, 3"), severity filter ("all criticals", "high and above"), or "all".

## phase 2 — fix via sub-agents

4. For each selected finding, spawn a sub-agent:
   - Independent findings (different files or layers) → **parallel**
   - Overlapping findings (same file or dependent changes) → **sequential**

5. **Sub-agent prompt:** load [assets/subagent-prompt.md](assets/subagent-prompt.md) and substitute all `<...>` placeholders with the finding's specific values before spawning.

## phase 3 — report

6. After all agents complete:
   - Table of findings fixed with commit hashes
   - Any findings that failed with the reason
   - Reminder to run `flutter test`

## commit format

See [assets/commit-format.md](assets/commit-format.md).

## rules

- Read `AGENTS.md` first.
- Verify findings against source files before fixing — never fix from the comment alone.
- One commit per finding (or per tightly coupled group).
- Stage only files relevant to each fix.
- `flutter test` must pass after every fix.
