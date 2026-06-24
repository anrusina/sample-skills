---
name: review-pr
description: "Comprehensive code review with severity-ranked findings and AI-ready fix prompts"
model: claude-sonnet-4-6
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
---

Perform a comprehensive code review on a GitHub PR for this project. Produces a structured review with a summary comment, inline comments on specific lines, severity-ranked findings, and "Prompt for AI" sections for each finding.

This skill is used in a multi-reviewer pipeline: a second AI model or the developer leaves review comments on GitHub, then `/fix-pr-findings` applies the fixes. Reviews from any author are valid input.

## inputs

- A full PR URL (e.g. `https://github.com/{owner}/{repo}/pull/42`)
- A PR number (e.g. `42`) — uses the current repo's remote
- A branch name — finds the open PR for that branch
- Just "review the PR" — finds the open PR for the current branch

## phase 1 — gather context

1. **Determine repo and PR number.** Derive owner/repo from `git remote get-url origin` if not in the input.

2. **Fetch PR metadata:**
   ```bash
   gh api repos/{owner}/{repo}/pulls/{number} \
     --jq '{title, body, state, base: .base.ref, head: .head.ref, user: .user.login, additions, deletions, commits}'
   ```

3. **Fetch the full diff** via `gh pr diff`. If >50KB, save to `/tmp/pr-{number}.diff`.

4. **Read `AGENTS.md`** — project constraints and Arrow of Intent requirements override any default review guidance.

5. **Fetch existing review comments** via `gh pr view --comments` to avoid duplicating prior feedback.

6. **Fetch linked issues for conformance checking.** Extract every `Closes #N` / `Fixes #N` / `Resolves #N` (and `Ref #N`) reference from the PR body. For each, fetch the issue body and all its comments:
   ```bash
   gh api repos/{owner}/{repo}/issues/{N} --jq '{title, body, state}'
   gh api repos/{owner}/{repo}/issues/{N}/comments --jq '[.[].body] | join("\n---\n")'
   ```
   Extract acceptance criteria from both body **and all comments** — `- [ ]` task-list items and content under "Acceptance criteria", "Done when", or "Requirements" headers. These are the ticket requirements the diff must satisfy. Skip if the PR body has no issue references.

## phase 2 — analyse

7. Analyse across these categories:

   - **Ticket conformance** — for each issue fetched in step 6, check the diff against every acceptance criterion. Flag any criterion with no corresponding change as a gap. Treat an unaddressed criterion on a `Closes #N` PR as at least **High** severity.
   - **Arrow of Intent** — code changes without an upstream spec or LLD; `@spec` tags pointing to missing specs; tests that implement spec behaviour but carry no `@spec` tag; HLD or LLD not updated to reflect the change
   - **Correctness** — wrong state transitions, inverted conditions, missing null safety, off-by-one errors, race conditions in async code
   - **Framework specifics** — load [flutter/review-categories.md](flutter/review-categories.md) for Flutter/Dart-specific checks <!-- TODO: replace with your framework's review categories -->
   - **Code quality** — dead code, unused imports, magic numbers, duplicated logic
   - **Architecture** — verify the project's layer rules from `AGENTS.md`; improper coupling between modules; missing abstractions for cross-cutting concerns
   - **Configuration** — hardcoded values that belong in constants, unsafe defaults
   - **Test coverage** — missing edge cases, state transitions not covered, assertions that verify nothing

8. **Verify every finding** against the actual source files — do not report from the diff alone.

9. **Classify each finding:**
   - **Critical** — Must fix before merge. Silent failures, broken spec contract, data loss.
   - **High** — Strong recommendation. Arrow of Intent violations, missing error handling, architecture issues.
   - **Medium** — Should address soon. Performance problems, incomplete implementations.
   - **Low** — Nits. Style, minor readability, non-blocking improvements.

## phase 3 — present and post

10. **Each inline comment body:** load [assets/inline-comment-template.md](assets/inline-comment-template.md) for the exact format, including the blast radius table and the "Prompt for AI" collapsible.

11. **Review summary body:** load [assets/summary-template.md](assets/summary-template.md) for the full structure.

12. **Show findings to the user before posting.** Output the full findings list (severity-ranked) in the conversation and ask: "Ready to post this review to GitHub? (yes / edit first / cancel)". Do NOT submit to GitHub yet.

13. **On user approval**, build the review JSON at `/tmp/review-{number}.json` and submit as one API call:
    ```bash
    gh api repos/{owner}/{repo}/pulls/{number}/reviews \
      --input /tmp/review-{number}.json
    ```
    Use `"event": "COMMENT"`.

14. **Report back:** review URL, findings count by severity, which are merge-blocking.

## rules

- Read `AGENTS.md` before reviewing.
- Fetch every linked issue and check the diff against its acceptance criteria — a `Closes #N` PR with unmet criteria is a finding.
- Verify every finding against source files — not just the diff.
- "What's done well" is mandatory — never skip it.
- Do not duplicate existing feedback.
- Every finding row must link to its inline comment.
- Every severity section must have a batch "Prompt for AI" toggle.
- One review, one API call.
- Always present findings in the conversation and wait for explicit approval before posting to GitHub, unless the invocation explicitly says to post directly (e.g. "review and post" or "--post").
- After posting, remind the developer they can use `/fix-pr-findings` to address findings.
