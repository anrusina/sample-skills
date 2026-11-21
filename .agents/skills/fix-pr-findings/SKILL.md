---
name: fix-pr-findings
description: "Triage a pull request's review findings, then fix the ones the developer picks: verifies each against the source, recommends fix, defer or leave-as-is with a rationale, and stops for the selection; then sub-agents commit and push one fix at a time, each thread gets an 'Addressed in' reply (never a resolve), and deferrals become issues. Use for '/fix-pr-findings [PR]', 'address the review comments', 'fix the findings on PR 12', or a coordinator relaying that request. Not for reviewing a PR (/review-pr) or the final merge cleanup (/pre-merge). Generic copy: if a project skill named `fix-pr-findings` is also listed, use that one instead."
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/../_shared/scripts/review-threads.sh *)
---

Orchestrate fixes for GitHub PR review findings from any reviewer (a second AI model, the developer, or `/review-pr`): fetch them, triage them for selection, and spawn sub-agents to apply each fix as its own commit.

## Project facts

<!-- facts:begin -->
This is the generic copy: work out the facts below as
[../_shared/facts.md](../_shared/facts.md) says. A row marked *shared* takes
its rule from there.

| Fact | How to find it |
|---|---|
| `<repo>` | *shared* |
| wrapper | *shared* |
| build-input docs | *shared* |
| skill names | *shared* |
| assets | *shared* |
<!-- facts:end -->

Pass the wrapper on to every sub-agent, with the row's rule.

## inputs

- A PR comment URL (e.g. `https://github.com/<repo>/pull/9#discussion_r188675`)
- A PR number with finding references (e.g. "PR #9, fix criticals" or "PR #9, fix #1 and #3")
- A PR number with an outside-diff finding reference (e.g. `PR #9, outside-diff finding #2`) — the finding lives in the review summary's *Outside the diff* section, not in a thread.
- Just "fix PR findings" — uses the open PR for the current branch

## phase 1 — gather findings

1. **Determine the PR.**
   - Extract the repo, PR number, and optional discussion ID from the URL if provided. If the URL's `owner/name` differs from `<repo>`, stop and say so — the fixes would land in the wrong checkout. A URL with a discussion ID (`#discussion_r<id>`) asks for that one finding: in step 2, keep only the thread whose comment URL carries that ID, and triage it alone.
   - If only a number is given, the PR is in `<repo>`.
   - If no number given, find the open PR via `gh pr list --head <branch>`.

2. **Fetch review comments (two calls — both required):**

   Top-level review bodies and conversation comments:
   ```bash
   gh pr view <number> --json comments,reviews
   ```

   Unresolved inline review threads, one JSON object each:
   ```bash
   ${CLAUDE_SKILL_DIR}/../_shared/scripts/review-threads.sh --wrap '<wrapper>' <number>
   ```

   Merge both sources, deduplicating by discussion URL (an inline comment also summarised in a review body appears once).

   Where a comment **lacks severity or blast radius**, assign them: severity (Critical / High / Medium / Low) from correctness impact, AGENTS.md rule violations and blast radius; blast radius (Isolated / Localised / Cross-cutting).

   Extract each finding: number, severity, blast radius, title, description, file(s) and line(s), discussion URL (for an outside-diff finding, the permalink in the review body).

3. **Triage each finding — recommend before asking.** Never fix on the reviewer's say-so alone: a reviewer can be wrong, out of scope, or contradicted by an upstream doc. Before presenting anything, verify each finding against the source file — and, for spec/doc findings, against the backing LLD and the Arrow of Intent — then assign exactly one recommendation:

   - **Fix** — correct and in scope for *this* PR; apply now.
   - **Defer** — valid, but fixing it here is blocked by a stated reason: a product or design decision not yet made, another subsystem or open issue (name it), or a change too big for this PR (say why). Low severity alone is not a reason — a valid Low finding is **Fix**. A deferred finding is always tracked: name the open issue that already covers it, or propose a new issue (type, priority, title and one-line scope) that phase 3 creates once the developer confirms. Never just a note.
   - **Leave as-is (by design)** — the current spec/code is intentional and the finding misreads intent. State the design reason.

   Never default to "fix all". Where a finding conflicts with another finding, the task brief, or an upstream doc (HLD/LLD/EARS), **surface the conflict and let the developer decide** — never resolve it silently. A finding may also be **partially** fixed (apply the in-scope half, defer the rest) — say which half and why.

   Apply the *Triage* section of each loaded asset.

4. **Present findings with the recommendation** (table includes Rec column):

   ```
   | # | Sev      | Blast radius  | Rec         | Title                             | File                          |
   |---|----------|---------------|-------------|-----------------------------------|-------------------------------|
   | 1 | Critical | Cross-cutting | Fix         | @spec tag references deleted spec | src/auth/session_store.ts     |
   | 2 | High     | Localised     | Defer       | Belongs to #42 storage refactor   | src/cart/cart_repository.ts   |
   | 3 | Medium   | Isolated      | Leave as-is | Early return kept intentionally   | src/checkout/summary_view.ts  |
   ```

   Follow the table with one block per finding, then any surfaced conflicts:

   ```
   **#1 — @spec tag references deleted spec** · Fix
   - **Rationale:** AUTH-004 was removed in the LLD rewrite; the tag now points at nothing.
   - **Solution:** Retag the test to AUTH-007, which replaced AUTH-004's behaviour.
   ```

   **Rationale** says why this recommendation. **Solution** says how: the concrete change for Fix (and for the in-scope half of a partial fix), where the follow-up goes and what it would change for Defer, and the reply to post on the thread for Leave-as-is.

   Then ask which findings to fix, **defaulting to the Fix-recommended set**. Accept: specific numbers ("1, 3"), severity filter ("all criticals", "high and above"), "all", or "as recommended". The developer's choice always overrides the recommendation.

   **Stop here until the developer answers.** No sub-agent starts before the selection.

## phase 2 — fix via sub-agents

5. **Check out the PR's branch, up to date.** Every sub-agent commits and pushes from this checkout, so it must be the PR's head branch at the remote's tip, with nothing uncommitted:
   ```bash
   gh pr view <number> --json headRefName -q .headRefName
   git branch --show-current
   git fetch origin
   git status --short --branch
   ```
   If the current branch is not the PR's head branch, or the tree has uncommitted changes, stop and say so. If the branch is only behind `origin/<head>`, `git pull --ff-only`; if it has diverged, stop and report.

6. For each selected finding (or tightly coupled group of findings), spawn a sub-agent, **one after another**: start the next only when the previous one has reported back (they share one checkout, index and push). Order them so a finding that another depends on goes first.

7. **Sub-agent prompt:** load [assets/subagent-prompt.md](assets/subagent-prompt.md) and substitute all `<...>` placeholders with the finding's specific values before spawning, including the *Fix* section of each loaded asset.

   If a sub-agent reports a failure (a gate it cannot make pass, a rejected push), stop the remaining fixes and report.

## phase 3 — report

Replies take the forms and commands in [../_shared/review-replies.md](../_shared/review-replies.md), on the thread or, for an outside-diff finding, in a PR comment that names it. Never resolve a thread: the next `/review-pr` does, once it has checked.

8. **Reply on each fixed finding:** `Addressed in <short-sha> — <what changed>.`

9. **Track each deferred finding the developer agreed to defer.** If an open issue covers it, reply `Tracked in #<N> — …`; otherwise search for a duplicate first (`gh issue list --search "<keyword>" --state all`), then run `/issue` for the proposed issue, with its type, priority and title, the finding, a link to the thread and the reason it can't be fixed in this PR, and reply `Captured as #<N> — …` with the number it reports. When part of a finding is fixed here, say which part in the reply, and make the issue cover the rest.

10. **Reply on each finding the developer chose to leave as-is:** `Left as-is: <reason>.`

11. After all agents complete:
   - Table of findings fixed with commit hashes, and deferred findings with their issue numbers
   - Any findings that failed with the reason
   - Anything the *Report* section of a loaded asset adds

## rules

- Every fix is a new commit on top of the branch, never an amend: reviewers re-check each fix by its commit.
