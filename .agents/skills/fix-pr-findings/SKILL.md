---
name: fix-pr-findings
description: "Orchestrate fixes for PR review findings via parallel sub-agents. Trigger: /fix-pr-findings <N>, or a request to address a PR's review findings, including one relayed by a coordinator session. Generic template: a project's own `fix-pr-findings` skill takes precedence."
---

Orchestrate fixes for GitHub PR review findings. Fetches review comments, presents findings for selection, and spawns sub-agents to apply each fix in isolation with properly formatted commits.

Findings may come from any reviewer — a second AI model, the developer, or `/review-pr`.

**Tool wrapper.** If `AGENTS.md` *Build and test commands* says tools run through a wrapper (for example a version manager's exec command), prefix every tool command below with it, `gh` included, and pass that on to every sub-agent.

## inputs

The repository is whatever `gh repo view --json nameWithOwner -q .nameWithOwner` reports for the current checkout — call it `$REPO` below.

- A PR comment URL (e.g. `https://github.com/$REPO/pull/9#discussion_r188675`)
- A PR number with finding references (e.g. "PR #9, fix criticals" or "PR #9, fix #1 and #3")
- A PR number with an outside-diff finding reference (e.g. `PR #9, outside-diff finding #2`) — the finding lives in the review summary's *Outside the diff* section, not in a thread.
- Just "fix PR findings" — uses the open PR for the current branch

## phase 1 — gather findings

1. **Determine the PR.**
   ```bash
   REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
   ```
   - Extract the repo, PR number, and optional discussion ID from the URL if provided. If the URL's `owner/name` differs from `$REPO`, stop and say so — the fixes would land in the wrong checkout.
   - If only a number is given, the PR is in `$REPO`.
   - If no number given, find the open PR via `gh pr list --head <branch>`.

2. **Fetch review comments (two calls — both required):**

   Top-level review bodies:
   ```bash
   gh pr view <number> --comments --json comments,reviews
   ```

   Unresolved inline review threads — GraphQL, because REST does not report
   resolution; resolved threads are already handled and are skipped:
   ```bash
   OWNER=${REPO%%/*}
   NAME=${REPO#*/}
   gh api graphql --paginate -F owner="$OWNER" -F name="$NAME" -F pr=<number> -f query='
   query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
     repository(owner: $owner, name: $name) { pullRequest(number: $pr) {
       reviewThreads(first: 100, after: $endCursor) {
         pageInfo { hasNextPage endCursor }
         nodes { id isResolved path line
           comments(first: 50) { nodes { databaseId body url author { login } } } } } } } }' \
     --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
   ```

   Merge both sources. Deduplicate by discussion URL — inline comments that are also summarised in a review body should appear once.

   For inline comments that **lack explicit severity or blast-radius metadata**, evaluate them before presenting:
   - Assign severity (Critical / High / Medium / Low) based on: correctness impact, AGENTS.md rule violations, and blast radius.
   - Note blast radius (Isolated / Localised / Cross-cutting).

   Extract each finding: number, severity, blast radius, title, description, file(s) and line(s), discussion URL.

   An outside-diff finding has a permalink instead of a discussion URL — read it from the review body fetched by the first call.

3. **Triage each finding — recommend before asking.** A reviewer (human or AI) can be wrong, out of scope, or contradicted by an upstream doc. Before presenting anything, verify each finding against the source file — and, for spec/doc findings, against the backing LLD and the Arrow of Intent — then assign exactly one recommendation:

   - **Fix** — correct and in scope for *this* PR; apply now.
   - **Defer** — valid, but fixing it here is blocked by a stated reason: a product or design decision not yet made, another subsystem or open issue (name it), or a change too big for this PR (say why). Low severity alone is not a reason — a valid Low finding is **Fix**. A deferred finding is always tracked: name the open issue that already covers it, or propose a new issue (title + one-line scope) that phase 3 creates once the developer confirms. Never just a note.
   - **Leave as-is (by design)** — the current spec/code is intentional and the finding misreads intent. State the design reason.

   Give a rationale and a proposed solution per finding (format in step 4). Never default to "fix all". Where a finding conflicts with another finding, the task brief, or an upstream doc (HLD/LLD/EARS), **surface the conflict and let the developer decide** — do not silently resolve it; consult before resolving any contradiction. A finding may also be **partially** fixed (e.g. apply the in-scope half, defer the rest) — say which half and why.

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

   **Stop here until the developer answers.** Triage is the whole of this turn; no sub-agent starts before the selection.

## phase 2 — fix via sub-agents

5. For each selected finding, spawn a sub-agent:
   - Independent findings (different files or layers) → **parallel**
   - Overlapping findings (same file or dependent changes) → **sequential**

6. **Sub-agent prompt:** load [assets/subagent-prompt.md](assets/subagent-prompt.md) and substitute all `<...>` placeholders with the finding's specific values before spawning.

## phase 3 — report

7. **Reply on each fixed thread — never resolve it.** Resolving is the next `/review-pr`'s call, once it has verified the fix:
   ```bash
   gh api repos/$REPO/pulls/<number>/comments/<first comment databaseId>/replies -f body='Addressed in <short-sha> — <what changed>.'
   ```
   An outside-diff finding has no thread — post a PR conversation comment instead:
   ```bash
   gh pr comment <number> --body 'Addressed in <short-sha> — outside-diff finding #<N>: <what changed>.'
   ```

7b. **Track each deferred finding the developer agreed to defer.** If an open issue covers it, reply `Tracked in #<N> — <reason it can't be fixed here>.`; otherwise create the proposed issue (as `/pre-merge` does for its follow-up items — labels and milestone chosen from those that exist on GitHub, never new ones) and reply `Captured as #<N> — <reason it can't be fixed here>.` — on the thread, or in a PR comment for an outside-diff finding. Never resolve the thread: the next `/review-pr` resolves it once it has checked that the issue covers whatever this PR leaves unfixed. When part of a finding is fixed here, say which part in the reply, and make the issue cover the rest.

8. After all agents complete:
   - Table of findings fixed with commit hashes, and deferred findings with their issue numbers
   - Any findings that failed with the reason
   - Reminder to run the project's quality gates (`AGENTS.md` *Build and test commands*) — unless every fix was documentation-only (Markdown / `docs/` only), in which case state that the gates were skipped because Markdown cannot affect them

## commit format

See [assets/commit-format.md](assets/commit-format.md).

## rules

- Read `AGENTS.md` first.
- Recommend **fix / defer / leave-as-is** with a rationale and proposed solution for every finding, and present it, before asking which to apply — never fix on the reviewer's say-so alone.
- Verify findings against source files before fixing — never fix from the comment alone.
- One commit per finding (or per tightly coupled group). Every fix is a new commit — never amend or rewrite commits already pushed for review.
- Never resolve a review thread — reply only.
- Stage only files relevant to each fix.
- Every quality gate in `AGENTS.md` *Build and test commands* must pass after every fix that touches code, tests, build configuration or any other build input. If that section lists no gates, ask the developer once for the commands, use them, and tell them to record them there. Skip the gates for a **documentation-only fix** — one whose changed files are all Markdown / under `docs/` — since Markdown cannot affect formatting, analysis or tests.
