---
name: review-pr
description: "Review a pull request as a skeptical senior engineer: checks the diff against its linked issues, the Arrow of Intent and the project's rules in an isolated worktree, runs the gates, re-checks earlier review threads (resolving or reopening them), and posts a severity-ranked review with inline comments and fix prompts once approved. Use for '/review-pr [PR]', 'review PR 12', 'look over this pull request', or a coordinator's request. Not for fixing findings (/fix-pr-findings) or merging (/pre-merge). Generic copy: if a project skill named `review-pr` is also listed, use that one instead."
allowed-tools:
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git blame *)
  - Bash(git grep *)
  - Bash(git -C * grep *)
  - Bash(git rev-parse *)
  - Bash(git rev-list *)
  - Bash(git merge-base *)
  - Bash(git symbolic-ref *)
  - Bash(git fetch *)
  - Bash(git branch *)
  - Bash(git switch *)
  - Bash(git checkout *)
  - Bash(git worktree *)
  - Bash(gh pr view *)
  - Bash(gh pr diff *)
  - Bash(gh pr list *)
  - Bash(gh pr comment *)
  - Bash(gh api *)
  - Bash(gh repo view *)
  - Agent
  - Bash(${CLAUDE_SKILL_DIR}/scripts/review-round.sh *)
  - Bash(${CLAUDE_SKILL_DIR}/../_shared/scripts/review-threads.sh *)
  - Bash(${CLAUDE_SKILL_DIR}/../_shared/scripts/worktree.sh *)
---

Review a GitHub PR: a summary comment, inline comments, severity-ranked findings, and a "Prompt for AI" for each finding. `/fix-pr-findings` applies the fixes; review comments from any author (another AI model, the developer) are valid input.

**Stance.** Assume each change fails until the source shows it does not: find why this code would break in production, not confirm that it works. No praise: the review carries findings, fixes and gate results, nothing else.

## Project facts

<!-- facts:begin -->
This is the generic copy: work out the facts below as
[../_shared/facts.md](../_shared/facts.md) says. A row marked *shared* takes
its rule from there.

| Fact | How to find it |
|---|---|
| `<repo>` | *shared* |
| `<base>` | *shared* |
| wrapper | *shared* |
| gates | *shared* |
| setup | *shared* |
| build-input docs | *shared* |
| fixtures | AGENTS.md testing section: git-ignored fixture folders that tests read from the primary checkout, and how to link them, or none (skip the fixture link) |
| blast-radius map | AGENTS.md: a section that maps the project's parts to the four blast-radius levels, or none (use the generic levels in the inline comment template) |
| skill names | *shared* |
| assets | *shared* |
<!-- facts:end -->

## inputs

- A full PR URL (e.g. `https://github.com/<owner>/<name>/pull/42`, for the repository `<repo>`)
- A PR number (e.g. `42`) — uses the current repo's remote
- A branch name — finds the open PR for that branch
- Just "review the PR" — finds the open PR for the current branch
- Optional `--deep` — adds the three history-and-context lenses in step 6a. Without it the review is a single pass. Use it on the first full review of a PR that changes existing production code, above all an area with a history of fixes (storage and migrations, concurrency, parsing, security). Skip it on follow-up rounds, documentation-only PRs and PRs that mostly add new files: the lenses read the changed lines' history, and those have little.
- Optional `--full` — forces a full review even when an earlier `/review-pr` round exists (see *Follow-up round* in phase 0).
- Optional `--post` — post without the approval stop in step 12.

## phase 0 — resolve the PR, then review in an isolated worktree

**Resolve the PR first, in the primary checkout.** If the input was a branch
name or nothing at all, find the number first with
`gh pr list --head <branch> --json number --jq '.[0].number'`. Then:

```bash
${CLAUDE_SKILL_DIR}/scripts/review-round.sh --wrap '<wrapper>' <number>   # add --full when it was passed
gh pr view <number> --json body -q .body
gh pr diff <number> --name-only
```

The script prints `key=value` lines; write each value in literally from here
on: `head` is `<head-branch>`, `head_sha` is `<head-sha>` (the exact commit
this review covers, used for every finding, the review's `commit_id` and the
step 13 check), `base` is `<base>`, and `last_sha` is `<last-sha>`.

**Eligibility.** If `state` is `CLOSED` or `MERGED`, stop and report there is
nothing to review. If `draft` is `true`, say so and ask whether to review
anyway.

**Follow-up round.** Every posted summary ends with a
`review-pr: reviewed <sha>` marker. On `round=follow-up`, the gates and
step 9 still cover the whole PR, but new findings are sought only in
`git diff <last-sha>..<head-sha>` (step 6b): code the last round passed is
not re-reviewed for fresh nits. A Critical defect anywhere is still
reported. On `round=full`, give the script's `reason=` in the summary.

**Never review in the primary checkout**: it routinely holds uncommitted
work. The review worktree, `<wt>` below, sits directly under the primary
checkout's `.claude/worktrees/`, never inside another worktree.

**Reuse this session's worktree on a re-run:** if this session already
created `<wt>` for this PR, move it to the new head:

```bash
${CLAUDE_SKILL_DIR}/../_shared/scripts/worktree.sh --wrap '<wrapper>' move <wt> <head-sha>
```

It prints `previous=<sha>` (`<prev-sha>`). The worktree setup below
survives the move; re-run a setup step only if
`git diff --name-only <prev-sha>..<head-sha>` touches its inputs (a
dependency manifest or lockfile for an install, a code-generation source for
code generation; each loaded asset's *Worktree setup* section names its
stack's). Never reuse a worktree this session did not create: another agent
may be reviewing in it.

Otherwise make a new one, pinned to `<head-sha>` rather than the moving
branch:

```bash
${CLAUDE_SKILL_DIR}/../_shared/scripts/worktree.sh --wrap '<wrapper>' add review-<number> <head-sha> --pr <number>
```

It prints `primary=<path>` (`<primary-checkout>`) and `worktree=<path>`
(`<wt>`); neither when the add failed. Every temp file this review writes
(the saved diff, the review JSON) is made with
`mktemp "${TMPDIR:-/tmp}/review-<number>-XXXXXX"`, never a fixed name, so
concurrent reviews don't collide.

`<wt>` is the working directory for everything below: run commands there
(`git -C <wt> …`, or the tool's own directory flag), never with `cd`, which
the allowlist doesn't cover. Leave it in place when the review ends; whoever
coordinates the PR (otherwise the developer) removes it after the merge.

**Set the worktree up before any gate.** A fresh worktree lacks the
git-ignored files the build needs (dependencies, generated code, a version
manager's trust), so gates there report phantom missing-file errors. Run
the *setup* steps in `<wt>` first, and apply the *Worktree setup* section of
each loaded asset. If *setup* is none and a gate then fails on missing
generated files or dependencies, ask the developer once for the setup
commands, use them, and tell them to record them in AGENTS.md *Worktree setup*.

**Documentation-only fast path.** If every changed path is Markdown or under
`docs/`, and none falls under a *build-input docs* path, skip the setup, the
gates and the fixture link. Record each gate in Verification as
`not run — documentation-only change set`. The review does not shrink:
step 6 applies the documentation categories in place of the code ones.

Otherwise run every *gates* command, in order, in `<wt>`, in check-only mode
wherever a gate would otherwise rewrite files (the loaded stack asset's
*Gates* section names it): the review never changes the PR's files. Also run
any guard script AGENTS.md lists among its checks.

Each gate's real result goes in the **Verification** section (step 11).
Errors from unresolved generated files or missing dependencies are a setup
gap, not findings.

If *fixtures* names any, link them into `<wt>` the way AGENTS.md describes
(typically `ln -sfn <primary-checkout>/<fixture-dir> <wt>/<fixture-dir>`) so
those tests run rather than skip silently; record any skips in Verification.

## phase 1 — gather context

1. **Repo, PR number, metadata and body** are already resolved in phase 0: reuse them rather than re-fetching.

2. **Fetch the full diff** via `gh pr diff <number>`. If >50KB, save it to a `mktemp` file (phase 0).

3. **Read `AGENTS.md`** — project constraints and Arrow of Intent requirements override any default review guidance.

4. **Fetch existing feedback** — conversation comments via `gh pr view <number> --comments`, and **every** review thread, resolved or not (one JSON object per thread), to avoid duplicating prior feedback and to re-check previous findings in step 9:
   ```bash
   ${CLAUDE_SKILL_DIR}/../_shared/scripts/review-threads.sh --wrap '<wrapper>' <number> --all
   ```

5. **Fetch linked issues for conformance checking.** Extract every `Closes #N` / `Fixes #N` / `Resolves #N` (and `Ref #N`) reference from the PR body. For each, fetch the issue body and all its comments:
   ```bash
   gh api repos/{owner}/{repo}/issues/<N> --jq '{title, body, state}'
   gh api repos/{owner}/{repo}/issues/<N>/comments --paginate --jq '.[] | .body + "\n---"'
   ```
   Extract acceptance criteria from the body **and every comment** equally (comments often add requirements or edge cases later): `- [ ]` task-list items and content under "Acceptance criteria", "Done when", or "Requirements" headers. These are the ticket requirements the diff must satisfy. Skip if the PR body has no issue references.

   **5a. Read the contracts the diff touches** — they are rarely in the changed file. Before analysing, for every changed public symbol (class, function, method, interface, state holder, repository, database table or schema), read in the worktree:
   - its declaration and the interface or abstract type it implements
   - its callers — `git -C <wt> grep -n '<symbol>'` — enough to know what they pass in and rely on coming back
   - the LLD section and the `docs/specs/EARS-<subsystem>.md` specs for the subsystem it belongs to

   A loaded field asset's *Review checks* section may name more to read for its kind of change. Judge the change against these, not against the diff alone.

## phase 2 — analyse

6. Analyse across these categories:

   - **Ticket conformance** — for each issue fetched in step 5, check the diff against every acceptance criterion; a criterion with no corresponding change is a gap, at least **High** on a `Closes #N` PR. If the LLD/spec the diff implements has itself drifted from the ticket's requirements, flag that too.
   - **Arrow of Intent** — code changes without an upstream spec or LLD; `@spec` tags pointing to missing specs; tests that implement spec behaviour but carry no `@spec` tag; HLD or LLD not updated to reflect the change
   - **Correctness** — wrong state transitions, inverted conditions, unhandled null or absent values, off-by-one errors, race conditions in async or concurrent code
   - **Async error handling** — an async operation neither awaited nor given an error path, so its failure vanishes; an awaited call outside any `try`/`catch` (or the language's equivalent) whose failure leaves state half-written (a partial storage write, a state holder stuck in a loading state); a `catch` that swallows the error without logging or surfacing it
   - **Cost on realistic input sizes** — the largest inputs the HLD, the LLDs or `AGENTS.md` describe for the subsystem: nested loops over those inputs, a repeated full scan where a lookup map would do, a per-item database query, allocation inside a render path or another hot loop
   - **Language and framework checks** — load [references/review-categories.md](references/review-categories.md) and apply every check in it to the changed code, then the *Review checks* section of the loaded stack asset (skip both on the documentation-only fast path).
   - **Field checks** — the *Review checks* section of each loaded field asset, with the severity floors it sets. A field asset points at the project's own rule lists (an AGENTS.md section, a checklist file it names); apply every rule there.
   - **Code quality** — dead code, magic numbers, and duplication: a block of logic repeated, or closely copied, in more than one place belongs in one shared function, and a repeated chunk of UI (several elements with their own layout or state) belongs in its own component. Count the copies the PR adds and new copies of code already on the default branch; searching the existing code for those may run as its own sub-agent in parallel with step 6. Flag copies that would have to change together, not short lines that happen to look alike. Usually **Low**; **Medium** when the copies already differ in a way that looks like a fix applied to only one of them.
   - **Architecture** — every layer rule in `AGENTS.md` (read in step 3), and `docs/dev/architecture.md` if the project has one
   - **Project rules no tool checks** — every rule `AGENTS.md` (or a `docs/dev/` guide it links) states that the gates cannot catch, checked on every changed file: logging and telemetry, the dependency policy (the check recorded next to each added or bumped dependency), component-catalog rules, error handling (no exception text in user-visible output, known failures caught by type), limits on non-null assertions, and any other rule of that kind. Apply each as `AGENTS.md` words it; a rule the project doesn't state is not a finding here.
   - **Configuration** — hardcoded values that belong in constants, unsafe defaults
   - **Component catalog coverage** — only if `AGENTS.md` names a component catalog: screens and reusable components have entries covering their named states, taken from the LLD that documents UI states (`AGENTS.md` or the HLD says which). Pure business-logic LLDs define no UI states, so need no coverage.
   - **Test coverage** — missing edge cases, state transitions not covered, assertions that verify nothing
   - **Test tiers** — only if AGENTS.md's testing section defines tiers: each new test file's tier fits the project's guide for choosing one (a tier guard only checks one exists); a test raised above its file clears the higher bar; a file carries any extra tag `AGENTS.md` requires (e.g. on tests that read git-ignored fixtures). An existing file's tier lowered with no reason in the PR description is **Medium**; a tier that looks wrong for the guide is **Low**.
   - **Documentation** — for any changed `docs/specs/` or `docs/design/` file, and the whole review on the documentation-only fast path, check the [design-doc rules](../_shared/design-doc-rules.md), that each changed subsystem's LLD still describes its current data flow and component boundaries, that the HLD still names the subsystems the code has, and that Mermaid diagrams in `docs/` match current names in the code. For a changed `.agents/skills/` file, check it against [../_shared/agentskills-best-practices.md](../_shared/agentskills-best-practices.md), its stale-reference checks included.

   **6a. Deep lenses (`--deep` only).** Run these three as parallel sub-agents, each given the PR number, `<head-sha>`, the changed-file list and `<wt>`, and each returning candidate findings with file, line and the evidence behind them:
   - **History** — `git log` and `git blame` of the changed lines: does the change undo an earlier fix, reintroduce a reverted approach, or break an invariant a past commit message explains?
   - **Earlier review feedback** — review comments on previous PRs that touched the same files (`git log --format=%H origin/<base> -- <path>`, then `gh api repos/{owner}/{repo}/commits/<sha>/pulls --jq '.[].number'` for each commit, deduplicated, then their review threads): does feedback given there apply here again?
   - **Code comments** — comments in the changed files that state a constraint (`must…`, `never…`, `why…`): does the change still honour them?

   Their candidates join yours and go through step 7 like any other.

   **6b. Follow-up round scope.** On a follow-up round, apply the step 6 categories to `git diff <last-sha>..<head-sha>` only, and add one check on those commits — **weakened tests**: flag any test in the range that lost an assertion, had an expected value changed to match new output, gained a skip marker, or was deleted along with its `@spec` tag, unless the commit's own change to the spec or LLD explains why.

   **6c. Unspecced behaviour.** Run on every round that changes production source code (the source tree AGENTS.md's project-structure section names — not tests, docs or configuration alone): the whole diff on a full review, `git diff <last-sha>..<head-sha>` on a follow-up round. Skip it on the documentation-only fast path. Where the Arrow of Intent category catches code with no spec at all, this catches a specced PR's unspecced decisions along the way. It may run as its own sub-agent in parallel with step 6, given the PR number, `<head-sha>`, the changed source files and `<wt>`, and returning candidates with file, line and evidence.

   For each behaviour the range adds or changes, find the EARS spec whose condition and action state it. Look for decisions a reader could not recover from the specs: a fallback or default, a guard that skips work, what is kept or reset on reload, a retry, an ordering or wait between two operations, a timing rule, a limit. A `@spec` tag on a nearby test or method does not make a behaviour specced; only a spec that describes it does.

   These are not candidates:
   - A refactor, a private helper, or a change with no observable behaviour
   - Look-and-feel, which belongs to the design system, not to EARS
   - Logging that carries no product intelligence
   - A branch that is only the limit case of an existing spec — name that spec in the summary's *Checked* line instead
   - Developer-only code under a recorded exception (`AGENTS.md`)

   Each surviving candidate is a finding and goes through steps 7 and 8 like any other. Its body uses the *Unspecced-behaviour variant* of [assets/inline-comment-template.md](assets/inline-comment-template.md): the behaviour, why speccing it helps, the test status, and a suggestion giving the LLD sentence first, then the spec, then any test. A suggested spec ID is the next free one in the namespace on the default branch; `/pre-merge` settles a clash with another open PR.

   Untested as well as unspecced is usually **Medium**; tested but unstated is usually **Low**. The fix-in default is this PR, docs before tests.

   **6d. Security review.** Run only when the project has a server, an API or authentication, or handles secrets or untrusted input from a network: `AGENTS.md` says so, or the changed code adds the first such piece. Otherwise, and on the documentation-only fast path, skip it and say so in the summary; on a follow-up round it covers the range only. Run Claude Code's built-in `/security-review` on the PR's changes in `<wt>`, as its own sub-agent in parallel with step 6 where the host allows (otherwise in this session); its candidates go through step 7 like any other. Where `/security-review` isn't available, record it as not run, with the reason. This is the starting point until the project has its own security checks.

   **Not findings.** Drop these before step 7:
   - Anything a gate (formatter, analyzer, linter, guard) reports — it belongs in Verification
   - A rule deliberately silenced in the code (a lint-suppression comment in the syntax the loaded stack asset's *Review checks* names, an exemption marker `AGENTS.md` defines) where the silencing comment gives a reason
   - A behaviour change that is clearly the point of the PR or follows directly from it
   - Pedantic nits a senior engineer would not raise
   - Restatements of existing feedback — match by file and symptom, not by line number; if an open thread already covers it, mention the thread in the summary rather than re-raising it

   A problem the PR did not cause — a pre-existing defect on lines it did not change, or a consequence the PR makes visible (a stale name next to one it renamed) — **is** a finding when worth raising, usually in *Outside the diff*. There is no unnumbered "follow-ups" list; anything worth mentioning gets a number, a severity and a step 8 fix-in decision.

7. **Verify every finding** against the actual source files, not the diff alone.

   For each finding, write its concrete failure scenario — the input or state that leads to the wrong behaviour. Confirmed in the source, the finding is **confirmed**. If not — it depends on runtime data, a caller you could not trace, or intent you could not establish — it is **unsure**: keep it, record in one line what you could not verify, and report and post it like any other, tagged **Unsure**. Never drop it silently or present it as confirmed.

8. **Classify each finding** — confirmed and unsure alike, by the impact it would have if real:
   - **Critical** — Must fix before merge. Silent failures, broken spec contract, data loss.
   - **High** — Strong recommendation. Arrow of Intent violations, missing error handling, architecture issues.
   - **Medium** — Should address soon. Performance problems on realistic input sizes, incomplete implementations.
   - **Low** — Style, minor readability, small improvements.

   A loaded asset's *Review checks* section may set a severity floor for its kind of finding; a floor raises a finding to that level, never lowers one.

   Severity says how bad it is, not whether it gets fixed. **Every finding, Low included, also gets a fix-in decision:**
   - **This PR** — the default. Fixed on this branch before merge.
   - **Follow-up issue — <reason>** — only when the reason is one of: it needs a product or design decision not yet made; it belongs to another subsystem or another open issue (name it); or the change is too big for this PR (say what makes it big). Suggest the issue's title. "Low severity" or "out of scope" alone is not a reason.

9. **Re-check previous findings.** Verify every thread from step 4 against the current source — including ones already marked `Verified fixed in`, since a later commit can reintroduce the defect — and decide:

   | Thread | Your verdict | Action |
   |---|---|---|
   | unresolved | fixed | reply `Verified fixed in <sha> — <what>`, then resolve |
   | resolved | not fixed | reply `Reopened: <what is still wrong>`, then unresolve |
   | resolved, already has a `Reopened:` reply | not fixed | reply only — leave the state for the developer |
   | resolved | fixed | no action — no reply either |
   | unresolved, deferred with a `Tracked in #N` or `Captured as #N` reply | #N is open, and the code at `<head-sha>` and #N's body together cover everything the finding raised | reply `Verified tracked in #N`, then resolve: a later session fixes the rest there |
   | unresolved, deferred the same way | #N is closed, or part of the finding is neither fixed nor in #N | reply `Not tracked: <what is left uncovered>` — leave it unresolved |
   | unresolved, with an `Addressed in` reply | not fixed | reply `Not fixed: <what is still wrong>` — leave it unresolved |
   | unresolved, with a `Left as-is:` reply | — | reply `Accepted as left`, then resolve: the developer decided |
   | anything else | — | no action |

   Reply before changing state ([../_shared/review-replies.md](../_shared/review-replies.md) has the forms and commands). `<sha>` is the commit that carries the fix.

   **The verdict comes from the code at `<head-sha>`, and nothing else** — not the fixer's `Addressed in <sha>` reply, and not what an earlier round in this conversation concluded. When a reply cites a commit, check it is on the branch (`git merge-base --is-ancestor <sha> <head-sha>`) and that it changes the thread's file or a file the finding's Suggestion/Prompt for AI names (`git show --name-only <sha>`). If either check fails, judge the thread on the code alone and say in the reply that the cited commit did not hold up.

   **Outside-diff findings** have no thread. Re-check each one that a PR conversation comment from step 4 names as `outside-diff finding #<N>` (an `Addressed in`, `Tracked in`, `Captured as` or `Left as-is:` reply), judged from the code at `<head-sha>` by the matching row above, and post that row's reply as a PR comment naming the finding.

## phase 3 — present findings for approval

10. **Each inline comment body:** load [assets/inline-comment-template.md](assets/inline-comment-template.md) for the exact format, including the blast radius levels and the "Prompt for AI" collapsible, and apply the *Inline comments* section of each loaded asset (the snippet language, a closing line for the prompt, blast-radius examples). A step 6c finding uses that file's *Unspecced-behaviour variant* instead of the default structure.

    GitHub accepts inline comments only on lines inside the diff's hunks, and one rejected comment fails the whole review call. A finding whose line falls outside every hunk — a caller of the changed code, a stale doc elsewhere — gets no inline comment: it goes in the summary's *Outside the diff* section, in the same comment format, linked by permalink `https://github.com/<repo>/blob/<head-sha>/<path>#L<start>-L<end>` with one line of context either side.

11. **Review summary body:** load [assets/summary-template.md](assets/summary-template.md) — the full template for a full review, its *Follow-up round* variant for a follow-up round — and add the rows the *Verification* section of each loaded asset names. Both end with the `review-pr: reviewed <head-sha>` marker the next round looks for. The **Verification** section, filled from the phase 0 gate run, is mandatory.

12. **Show findings to the user before posting.** In the conversation, output:
    - the findings, severity-ranked, one entry each, with its fix-in decision (step 8) and a mark on any that will post outside the diff (step 10)
    - the unsure findings as their own section, each with its severity and the line on what could not be verified
    - the step 9 thread actions (resolve / reopen / reply-only), each with its reply

    Then ask: "Ready to post this review to GitHub? (yes / edit first / cancel)". Do NOT submit to GitHub yet. With `--post`, show the list but don't ask: go straight to step 13.

13. **On approval, or with `--post`**, first re-check the PR is unchanged since phase 0:
    ```bash
    gh api repos/{owner}/{repo}/pulls/<number> --jq '{state, head_sha: .head.sha}'
    ```
    If `state` is now `closed`, stop and report — do not post. If `head_sha` differs from `<head-sha>`, new commits landed during the review: stop, tell the user which commits arrived, and ask whether to post against the reviewed commit anyway or re-run the review. Do not post silently.

    Then write the review JSON to a file made with `mktemp` (phase 0), `<review-json>` below, and submit it as one API call, removing the file whether or not the call succeeds:
    ```bash
    gh api repos/{owner}/{repo}/pulls/<number>/reviews --input <review-json>; rc=$?; rm -f <review-json>; exit $rc
    ```
    Use `"event": "COMMENT"` and `"commit_id": "<head-sha>"`, so inline comments anchor to the lines that were actually reviewed. If the call fails, fix the cause, write a fresh file and submit again.

    Then carry out the step 9 thread actions, the reply first, then the state change, with the commands in [../_shared/review-replies.md](../_shared/review-replies.md).

14. **Report back:** review URL, findings count by severity, how many of them are unsure, which are merge-blocking, and threads resolved / reopened.

## rules

- Review against the default branch only. Never read other open PRs or branches, not for spec IDs and not for conflicts: `/pre-merge` settles those when the PR merges.
- After posting, remind the developer they can use `/fix-pr-findings` to address the findings.
