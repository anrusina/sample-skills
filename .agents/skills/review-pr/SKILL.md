---
name: review-pr
description: "Comprehensive code review with severity-ranked findings and AI-ready fix prompts. Trigger: /review-pr <N>, or a request to review a pull request, including one relayed by a coordinator session. Generic template: a project's own `review-pr` skill takes precedence."
allowed-tools:
  - Bash(git *)
  - Bash(gh *)
  - Agent
---

Perform a comprehensive code review on a GitHub PR. Produces a structured review with a summary comment, inline comments on specific lines, severity-ranked findings, and "Prompt for AI" sections for each finding.

This skill is used in a multi-reviewer pipeline: a second AI model or the developer leaves review comments on GitHub, then `/fix-pr-findings` applies the fixes. Reviews from any author are valid input.

**Stance.** Assume each change fails until the source shows it does not — the job is to find why this code would break in production, not to confirm that it works. No praise: the review carries findings, fixes and the gate results, nothing else.

## Project facts

<!-- facts:begin -->
This is the generic copy: no project facts are written into it. Work out each
fact below once, at the start of the run, then write its value literally into
every command that needs it. Each Bash call starts a fresh shell, so a variable
set in one call is empty in the next; never carry a value across calls in a
shell variable.

| Fact | How to find it |
|---|---|
| `<repo>` | `gh repo view --json nameWithOwner -q .nameWithOwner` |
| `<base>` | `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`; if that fails, `git symbolic-ref --short refs/remotes/origin/HEAD \| sed 's\|^origin/\|\|'` |
| wrapper | AGENTS.md build section: the prefix the toolchain runs through (a version manager's exec command, for example), or none. Run the gates, and each tool the wrapper provides (the tools its config file lists), through it; pass it to this skill's scripts as `--wrap '<wrapper>'`; run every other command bare, so it matches `allowed-tools` |
| gates | AGENTS.md build section: the format, lint/analyze and test commands, in order, or the one command that runs them all |
| setup | AGENTS.md *Worktree setup*: the steps a fresh worktree needs (dependencies, code generation), or none |
| build-input docs | AGENTS.md *Project structure*: Markdown the build reads, or none. Whatever AGENTS.md says, Markdown or MDX inside the source tree that the build reads (content collections, MDX pages, a docs site's sources) counts too. A change to any of it runs the gates like code |
| fixtures | AGENTS.md testing section: git-ignored fixture folders that tests read from the primary checkout, and how to link them, or none (skip the fixture link) |
| blast-radius map | AGENTS.md: a section that maps the project's parts to the four blast-radius levels, or none (use the generic levels in the inline comment template) |
| skill names | `/<name>` when the primary checkout (`dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`) holds the skill in `.agents/skills/<name>/` or `.claude/skills/<name>/`; otherwise the form this skill was installed in: `/sample-skills:<name>` from the plugin, `sample-skills-<name>` from a Codex install. Other skills are named in this file in their short form (`/<name>`); write each in the form this rule gives |
| assets | the stack and field assets that apply: see *Assets* below |

**AGENTS.md sections by role.** Projects name sections differently. The build
section is the one that lists the build, format, lint and test commands,
whatever it is called (*Build and test commands*, *Build commands*, *Tools*,
*Commands*). Match every section this skill reads the same way: by what it
holds, not by its exact title. When a required fact is missing, ask the
developer once, use the answer, and tell them which AGENTS.md section to
record it in.

**Assets.** This skill keeps stack and field assets under `assets/stack/` and
`assets/field/`; `assets/index.md` says when each applies. At the start of the
run, load every asset whose condition holds, and apply each where a step names
its section. With none loaded, the steps' generic text applies.
<!-- facts:end -->

## inputs

- A full PR URL (e.g. `https://github.com/<owner>/<name>/pull/42`, for the repository `<repo>`)
- A PR number (e.g. `42`) — uses the current repo's remote
- A branch name — finds the open PR for that branch
- Just "review the PR" — finds the open PR for the current branch
- Optional `--deep` — adds the three history-and-context lenses in step 6a. Without it the review is a single pass.
- Optional `--full` — forces a full review even when an earlier `/review-pr` round exists (see *Follow-up round* in phase 0).
- Optional `--post` — post without the approval stop in step 12 (see *rules*).

## phase 0 — resolve the PR, then review in an isolated worktree

**Resolve the PR first, in the primary checkout.** If the input was a branch
name or nothing at all, find the number first with
`gh pr list --head <branch> --json number --jq '.[0].number'`. Then:

```bash
gh api repos/{owner}/{repo}/pulls/<number> \
  --jq '{title, body, state, draft, merged, base: .base.ref, head: .head.ref, head_sha: .head.sha, user: .user.login, additions, deletions, commits}'
gh pr diff <number> --name-only
```

`gh` fills `{owner}` and `{repo}` itself from the current checkout. Every
command below that names the default branch uses `origin/<base>`.

**Eligibility.** If `state` is `closed` (merged or not), stop and report
that — there is nothing to review. If `draft` is true, say so and ask
whether to review anyway before going further.

The head ref is `<head-branch>` below; `head_sha` is `<head-sha>` — the exact
commit this review covers. Record it: every finding, the review's
`commit_id`, and the pre-post check in step 13 depend on it.

**Follow-up round.** Every posted summary ends with a marker recording the
commit it reviewed. Find the latest one:

```bash
gh api "repos/{owner}/{repo}/pulls/<number>/reviews?per_page=100" \
  --jq '[.[].body | select(test("review-pr: reviewed [0-9a-f]{40}")) | capture("review-pr: reviewed (?<sha>[0-9a-f]{40})").sha] | last // empty'
```

If a marker gives `<last-sha>`, `git merge-base --is-ancestor <last-sha> <head-sha>`
succeeds, `git rev-list --merges <last-sha>..<head-sha>` is empty, and `--full`
was not passed, this run is a **follow-up round**:
the gates and step 9 still cover the whole PR, but new findings are sought
only in `git diff <last-sha>..<head-sha>` — the commits since the last round
(step 6b). Code the last round already passed is not re-reviewed for fresh
nits; that is what keeps a reviewer and a fixer from trading Low findings
indefinitely. A Critical defect anywhere is still reported. If there is no
marker, `<last-sha>` is no longer an ancestor (the branch was rebased or
force-pushed), or a merge commit exists in `<last-sha>..<head-sha>` (the
default branch was merged in), run a full review and say why in the summary.

**Never review in the primary checkout** — it routinely holds uncommitted
work. The review worktree is `<wt>` below: an absolute path directly under the
primary checkout's `.claude/worktrees/`, never inside another worktree.

**Reuse this session's worktree on a re-run:** if this session already
created `<wt>` for this PR, move it to the new head instead of creating
another —

```bash
git fetch origin
git -C <wt> rev-parse HEAD
git -C <wt> checkout --detach <head-sha>
```

— note the commit the second command prints as `<prev-sha>`, and keep the
worktree's `<suffix>`. The worktree setup below (installed dependencies,
generated code, linked fixtures, local tool trust) survives the checkout;
re-run a setup step only if `git diff --name-only <prev-sha>..<head-sha>`
touches that step's inputs — a dependency manifest or lockfile for a
dependency install, a code-generation source for code generation. The
*Worktree setup* section of each loaded asset names its stack's inputs. Never
reuse a worktree this session did not create — another agent may be reviewing
in it.

Otherwise, use a new worktree pinned to `<head-sha>`, not the moving branch,
under the primary checkout:

```bash
git fetch origin
# The primary checkout, wherever this session runs: started inside another
# worktree, a relative path would nest the new one under it.
ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
git worktree add "$ROOT/.claude/worktrees/review-<number>-<suffix>" <head-sha>
echo "$ROOT/.claude/worktrees/review-<number>-<suffix>"
```

The path it prints is `<wt>`: write it in literally from here on.
`<suffix>` is 6 random hex characters you pick (e.g. `review-42-a3f9c1`), so
concurrent reviews of the same PR by different agents get separate
worktrees. If git reports the path already exists, pick another suffix.
Every temp file this review writes (the saved diff, the review JSON) is made
with `mktemp "${TMPDIR:-/tmp}/review-<number>-<suffix>-XXXXXX"`, never a fixed
name, so concurrent reviews never overwrite each other's files; note the path
it prints and write it in literally later.

`<wt>` is the working directory for everything below — run the commands there
(`git -C <wt> …`, or the tool's own directory flag) rather than issuing a
`cd`, which nothing in the allowlist covers. Leave it in place when the review
ends; the developer cleans up worktrees in bulk.

**Set the worktree up before any gate.** A fresh worktree has none of the
git-ignored files the build needs — installed dependencies, generated code,
a version manager's trust for the directory — so a gate run there can report
hundreds of phantom missing-file errors that say nothing about the PR. Run
the *setup* steps in `<wt>` first, and apply the *Worktree setup* section of
each loaded asset. If *setup* is none and a gate then fails on missing
generated files or dependencies, ask the developer once for the setup
commands, use them, and tell them to record them in AGENTS.md *Worktree setup*.

**Documentation-only fast path.** If every changed path is Markdown or under
`docs/`, and none falls under a *build-input docs* path (Markdown the build
reads is a build input, not documentation), skip the setup, the gates and the
fixture link. Record each gate in Verification as
`not run — documentation-only change set`. Skipping the gates does not shrink
the review: step 6 applies the documentation categories in place of the code
ones.

Otherwise the gates are now meaningful. Run every *gates* command, in order,
in `<wt>`. Use a gate's check-only mode wherever it would otherwise rewrite
files (a formatter's check or dry-run flag; the *Gates* section of the loaded
stack asset names it): the review never changes the PR's files. Also run any
guard script AGENTS.md lists among its checks — guards catch project rules the
analyzer has no rule for.

Each gate's real result goes in the **Verification** section (step 11).
Errors from unresolved generated files or missing dependencies are a setup
gap, not findings.

If *fixtures* names any, link them into `<wt>` the way AGENTS.md describes
(typically `ln -sfn <primary-checkout>/<fixture-dir> <wt>/<fixture-dir>`) so
those tests run rather than skip. Without it they skip silently — record
skips in Verification.

## phase 1 — gather context

1. **Repo, PR number and metadata** are already resolved in phase 0 — reuse them rather than re-fetching.

2. **Fetch the full diff** via `gh pr diff <number>`. If >50KB, save it to a file made with `mktemp` as phase 0 describes. Phase 0 fetched only the file *names*, for the fast-path decision; this is the diff content itself.

3. **Read `AGENTS.md`** — project constraints and Arrow of Intent requirements override any default review guidance.

4. **Fetch existing feedback** — conversation comments via `gh pr view <number> --comments`, and **every** review thread, resolved or not, via GraphQL. Used to avoid duplicating prior feedback and to re-check previous findings in step 9. `<owner>` and `<name>` are the two halves of `<repo>`, written in:
   ```bash
   gh api graphql --paginate -F owner=<owner> -F name=<name> -F pr=<number> -f query='
   query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
     repository(owner: $owner, name: $name) { pullRequest(number: $pr) {
       reviewThreads(first: 100, after: $endCursor) {
         pageInfo { hasNextPage endCursor }
         nodes { id isResolved path line
           comments(first: 50) { nodes { databaseId body url author { login } } } } } } } }' \
     --jq '.data.repository.pullRequest.reviewThreads.nodes[]'
   ```

5. **Fetch linked issues for conformance checking.** Extract every `Closes #N` / `Fixes #N` / `Resolves #N` (and `Ref #N`) reference from the PR body. For each, fetch the issue body and all its comments:
   ```bash
   gh api repos/{owner}/{repo}/issues/<N> --jq '{title, body, state}'
   gh api repos/{owner}/{repo}/issues/<N>/comments --paginate --jq '.[] | .body + "\n---"'
   ```
   Extract acceptance criteria from both body **and all comments** — `- [ ]` task-list items and content under "Acceptance criteria", "Done when", or "Requirements" headers. Comments may contain requirements or edge cases added after the issue was written; treat them equally. These are the ticket requirements the diff must satisfy. Skip if the PR body has no issue references.

   **5a. Read the contracts the diff touches.** Most real bugs are a mismatch between changed code and the contract it must honour, and that contract is rarely in the changed file. Before analysing, for every changed public symbol (class, function, method, interface, state holder, repository, database table or schema), read in the worktree:
   - its declaration and the interface or abstract type it implements
   - its callers — `git -C <wt> grep -n '<symbol>'` — enough to know what they pass in and rely on coming back
   - the LLD section and the `docs/specs/EARS-<subsystem>.md` specs for the subsystem it belongs to

   A loaded field asset's *Review checks* section may name more to read for its kind of change. Judge the change against these, not against the diff alone.

## phase 2 — analyse

6. Analyse across these categories:

   - **Ticket conformance** — for each issue fetched in step 5, check the diff against every acceptance criterion. Flag any criterion with no corresponding change as a gap: the PR claims to `Closes #N` but does not fully satisfy the ticket. If the LLD/spec the diff implements appears to have itself drifted from the ticket's requirements, flag that too. Treat an unaddressed criterion on a `Closes #N` PR as at least **High** severity.
   - **Arrow of Intent** — code changes without an upstream spec or LLD; `@spec` tags pointing to missing specs; tests that implement spec behaviour but carry no `@spec` tag; HLD or LLD not updated to reflect the change
   - **Correctness** — wrong state transitions, inverted conditions, unhandled null or absent values, off-by-one errors, race conditions in async or concurrent code
   - **Async error handling** — an async operation neither awaited nor given an error path, so its failure vanishes; an awaited call outside any `try`/`catch` (or the language's equivalent) whose failure leaves state half-written (a partial storage write, a state holder stuck in a loading state); a `catch` that swallows the error without logging or surfacing it
   - **Cost on realistic input sizes** — the largest inputs the HLD, the LLDs or `AGENTS.md` describe for the subsystem: nested loops over those inputs, a repeated full scan where a lookup map would do, a per-item database query, allocation inside a render path or another hot loop
   - **Language and framework checks** — load [references/review-categories.md](references/review-categories.md) and apply every check in it to the changed code, then the *Review checks* section of the loaded stack asset (skip both on the documentation-only fast path). The references file holds the failure classes every stack shares; the stack asset adds its framework's own.
   - **Field checks** — the *Review checks* section of each loaded field asset, with the severity floors it sets. A field asset points at the project's own rule lists (an AGENTS.md section, a checklist file it names); apply every rule there.
   - **Code quality** — dead code, magic numbers, duplicated logic
   - **Architecture** — every layer rule in `AGENTS.md` (read in step 3), and `docs/dev/architecture.md` if the project has one
   - **Project rules no tool checks** — the `AGENTS.md` rules the gates cannot catch, checked explicitly on every changed file. Each item applies when `AGENTS.md` (or a `docs/dev/` guide it links) states the rule:
     - Logging — each event `AGENTS.md` requires is logged at its level; every caught exception that is logged carries both the error and its stack trace; no ad-hoc console output in place of the project's logger, no static or global logger where injection is required, no PII
     - Telemetry signals — an LLD that documents log events with product intelligence has a `## Telemetry signals` section, denominator first, failures as rate pairs
     - Dependency policy — any added or bumped dependency has the policy check recorded next to it (AGENTS.md's dependency-policy section, for example *Security → Dependency policy*; when there is none, the default is a version published at least 14 days ago, with the check recorded beside the dependency)
     - Component catalog actions — if `AGENTS.md` names a component catalog, no interactive control in it is wired to an empty handler; every one reports its action
     - Failure presentation — no exception's message, type or stack reaches user-visible text (string-interpolating the error, calling its to-string in a view); work that can throw runs in the state layer, not in a render function; a known failure is caught by its named type, not by a bare catch-all that would also hide defects from the app-wide error boundary (the only exceptions are catch-alls their LLD records, which still log at the level `AGENTS.md` sets for them); a new failure presentation reuses one of the surfaces `AGENTS.md`'s error-handling rules name rather than a hand-made box or dialog, and a new surface carries its LLD's reason; every failure state is registered in the component catalog where `AGENTS.md` requires it
     - Non-null assertions — where `AGENTS.md` restricts them (e.g. requires a comment saying why the value cannot be absent there), every new one complies
   - **Configuration** — hardcoded values that belong in constants, unsafe defaults
   - **Component catalog coverage** — only if `AGENTS.md` names a component catalog: screens and reusable components have entries covering their named states. State names come from the LLD that documents UI states (`AGENTS.md` or the HLD says which). LLDs that are pure business logic define no UI states — coverage is not required from their specs.
   - **Test coverage** — missing edge cases, state transitions not covered, assertions that verify nothing
   - **Test tiers** — only if AGENTS.md's testing section defines tiers: each new test file's tier fits the project's guide for choosing one; a test raised above its file clears the higher bar; a file carries any extra tag `AGENTS.md` requires (e.g. on tests that read git-ignored fixtures). An existing file whose tier was lowered with no reason in the PR description is a **Medium** finding; a tier that looks wrong for the guide is **Low**. A tier guard only checks that a tier exists, not that it is the right one.
   - **Documentation** — for any changed `docs/specs/` or `docs/design/` file, and the whole review on the documentation-only fast path, apply the `/doc-audit` checks (its steps 3–5: LLD, HLD and diagrams) and the `AGENTS.md` Arrow of Intent rules: an LLD or HLD citing individual EARS IDs; look-and-feel values pinned in an LLD, including a token that restates its literal value; a `> Note:` that narrates another subsystem's internals; a renumbered stable ID (OQ-N, spec IDs); an LLD with log events but no `## Telemetry signals` section. For a changed `.agents/skills/` file, apply `/doc-audit` step 7.

   **6a. Deep lenses (`--deep` only).** Run these three as parallel sub-agents, each given the PR number, `<head-sha>`, the changed-file list and `<wt>`, and each returning candidate findings with file, line and the evidence behind them:
   - **History** — `git log` and `git blame` of the changed lines: does the change undo an earlier fix, reintroduce a reverted approach, or break an invariant a past commit message explains?
   - **Earlier review feedback** — review comments on previous PRs that touched the same files (`git log --format=%H origin/<base> -- <path>`, then `gh api repos/{owner}/{repo}/commits/<sha>/pulls --jq '.[].number'` for each commit, deduplicated, then their review threads): does feedback given there apply here again?
   - **Code comments** — comments in the changed files that state a constraint (`must…`, `never…`, `why…`): does the change still honour them?

   Their candidates join yours and go through step 7 like any other.

   **6b. Follow-up round scope.** On a follow-up round (phase 0), apply the step 6 categories to `git diff <last-sha>..<head-sha>` only, and add one check on those commits — **weakened tests**. A fix can make a finding disappear by changing the test instead of the code. Flag any test in the range that lost an assertion, had an expected value changed to match new output, gained a skip marker, or was deleted along with its `@spec` tag, unless the commit's own change to the spec or LLD explains why.

   **6c. Unspecced behaviour.** Run on every round that changes production source code (the source tree AGENTS.md's project-structure section names — not tests, docs or configuration alone) — the whole diff on a full review, `git diff <last-sha>..<head-sha>` on a follow-up round. Skip it on the documentation-only fast path. The Arrow of Intent category above catches code with no spec at all; this check catches the quieter case, where a PR's main behaviour is specced and a decision made along the way is not. It reads code rather than the diff's intent, so it may run as its own sub-agent in parallel with step 6, given the PR number, `<head-sha>`, the changed source files and `<wt>`, and returning candidates with file, line and evidence.

   For each behaviour the range adds or changes, find the EARS spec whose condition and action state it. Look for decisions a reader could not recover from the specs: a fallback or default, a guard that skips work, what is kept or reset when something reloads, a retry, an ordering or wait between two operations, a timing rule, a limit. A behaviour is specced when a spec describes it — a `@spec` tag on a nearby test or method does not make it so.

   These are not candidates:
   - A refactor, a private helper, or a change with no observable behaviour
   - Look-and-feel, which belongs to the design system, not to EARS
   - Logging that carries no product intelligence
   - A branch that is only the limit case of an existing spec — name that spec in the summary's *Checked* line instead
   - Developer-only code under a recorded exception (`AGENTS.md`)

   Each candidate that survives becomes a finding and goes through steps 7 and 8 like any other. Its body uses the *Unspecced-behaviour variant* of [assets/inline-comment-template.md](assets/inline-comment-template.md), which has a labelled line for each of these:
   - **The behaviour** — what the code does, at which file and line
   - **The suggested addition** — the spec written out in EARS form with a suggested ID (the next free one in the subsystem's namespace on the default branch; a clash with another open PR is settled by `/pre-merge` when one of them merges), or the reworded text when an existing spec should be tightened instead of a new one added
   - **The LLD sentence it needs first** — which LLD section must state the behaviour before the spec can be derived from it; a spec with no backing LLD text is itself an Arrow of Intent violation
   - **Why speccing it helps** — what could change or regress unnoticed without it, or what a later reader or reviewer could not tell is intended
   - **Test status** — whether a test already exercises the behaviour, and under which `@spec` tag

   Untested as well as unspecced is usually **Medium**; tested but unstated is usually **Low**. The fix-in default is this PR, docs before tests.

   **Not findings.** Drop these before step 7 — they cost the reader attention and cost `/fix-pr-findings` a triage each:
   - Anything the gates report — it is already in Verification
   - A rule deliberately silenced in the code (a lint-suppression comment in the syntax the loaded stack asset's *Review checks* names, an exemption marker `AGENTS.md` defines) where the silencing comment gives a reason
   - A behaviour change that is clearly the point of the PR or follows directly from it
   - Pedantic nits a senior engineer would not raise
   - Restatements of existing feedback — match by file and symptom, not by line number; if an open thread already covers it, mention the thread in the summary rather than re-raising it

   A problem the PR did not cause — a pre-existing defect on lines it did not change, or a consequence the PR makes visible (a stale name next to one it renamed) — **is** a finding when worth raising: it goes through step 7 like any other, usually in *Outside the diff*. There is no unnumbered "follow-ups" list; anything worth mentioning gets a number, a severity and a step 8 fix-in decision.

7. **Verify every finding** against the actual source files — do not report from the diff alone. Anything a gate (formatter, analyzer, linter, guard) reports belongs in Verification, not in findings — the gates already surface it.

   For each finding, write its concrete failure scenario — the input or state that leads to the wrong behaviour. If you confirmed that scenario in the source, the finding is **confirmed**. If you could not — the scenario depends on runtime data, a caller you could not trace, or intent you could not establish — the finding is **unsure**: keep it, and record in one line what you could not verify. Unsure findings are reported and posted like any other, tagged so the reader knows where to look harder.

8. **Classify each finding** — confirmed and unsure alike, by the impact it would have if real:
   - **Critical** — Must fix before merge. Silent failures, broken spec contract, data loss.
   - **High** — Strong recommendation. Arrow of Intent violations, missing error handling, architecture issues.
   - **Medium** — Should address soon. Performance problems on realistic input sizes, incomplete implementations.
   - **Low** — Style, minor readability, small improvements.

   A loaded asset's *Review checks* section may set a severity floor for its kind of finding; a floor raises a finding to that level, never lowers one.

   Severity says how bad it is, not whether it gets fixed. **Every finding, Low included, also gets a fix-in decision:**
   - **This PR** — the default. Fixed on this branch before merge.
   - **Follow-up issue — <reason>** — only when the reason is one of: it needs a product or design decision not yet made; it belongs to another subsystem or another open issue (name it); or the change is too big for this PR (say what makes it big). Suggest the issue's title. "Low severity" or "out of scope" alone is not a reason.

   No finding is optional: each one ends either fixed in this PR or tracked as an issue.

9. **Re-check previous findings.** Verify every thread from step 4 against the current source — including ones already marked `Verified fixed in`, since a later commit can reintroduce the defect — and decide:

   | Thread | Your verdict | Action |
   |---|---|---|
   | unresolved | fixed | reply `Verified fixed in <sha> — <what>`, then resolve |
   | resolved | not fixed | reply `Reopened: <what is still wrong>`, then unresolve |
   | resolved, already has a `Reopened:` reply | not fixed | reply only — leave the state for the developer |
   | resolved | fixed | no action — no reply either |
   | unresolved, deferred with a `Tracked in #N` or `Captured as #N` reply | #N is open, and the code at `<head-sha>` and #N's body together cover everything the finding raised | reply `Verified tracked in #N`, then resolve: a later session fixes the rest there |
   | unresolved, deferred the same way | #N is closed, or part of the finding is neither fixed nor in #N | reply `Not tracked: <what is left uncovered>` — leave it unresolved |
   | anything else | — | no action |

   Always reply before changing state — every agent posts as the same account, so the reply is the only record of who decided what. `<sha>` is the commit that carries the fix. The "reply only" row stops two reviewers flipping one thread back and forth.

   **The verdict comes from the code at `<head-sha>`, and nothing else.** Not the fixer's `Addressed in <sha>` reply, and not what an earlier round in this conversation concluded — a long review session remembers its own judgments, and a fixer's reply is a claim to verify. When a reply cites a commit, check it is on the branch (`git merge-base --is-ancestor <sha> <head-sha>`) and that it changes the thread's file or a file the finding's Suggestion/Prompt for AI names (`git show --name-only <sha>`). A citation that fails either check proves nothing: judge the thread on the code alone and say in the reply that the cited commit did not hold up.

   **Outside-diff findings** have no thread. Re-check each one that a PR conversation comment from step 4 marks `Addressed in <sha> — outside-diff finding #<N>`, judged from the code at `<head-sha>` exactly as above. Post the verdict as a PR conversation comment — there is no thread to resolve or unresolve: `Verified fixed in <sha> — outside-diff finding #<N>: <what>` or `Reopened: outside-diff finding #<N> — <what is still wrong>`.

## phase 3 — present findings for approval

10. **Each inline comment body:** load [assets/inline-comment-template.md](assets/inline-comment-template.md) for the exact format, including the blast radius levels and the "Prompt for AI" collapsible, and apply the *Inline comments* section of each loaded asset (the snippet language, a closing line for the prompt, blast-radius examples). A step 6c finding uses that file's *Unspecced-behaviour variant* instead of the default structure.

    GitHub accepts inline comments only on lines inside the diff's hunks, and one rejected comment fails the whole review call. A finding whose line falls outside every hunk — a caller of the changed code, a stale doc elsewhere — gets no inline comment: it goes in the summary's *Outside the diff* section, in the same comment format, linked by permalink `https://github.com/<repo>/blob/<head-sha>/<path>#L<start>-L<end>` with one line of context either side.

11. **Review summary body:** load [assets/summary-template.md](assets/summary-template.md) for the full structure — the full template for a full review, its *Follow-up round* variant for a follow-up round — and add the rows the *Verification* section of each loaded asset names. Both end with the `review-pr: reviewed <head-sha>` marker the next round looks for. The **Verification** section is mandatory and is filled from the phase 0 gate run — a review that reports findings without saying what was actually run leaves the reader unable to weigh them.

12. **Show findings to the user before posting.** Output the full findings list (severity-ranked, one entry per finding), then the unsure findings as their own section — each with its severity and the one line on what could not be verified — marking any finding that will post outside the diff (step 10) and each finding's fix-in decision (step 8), followed by the step 9 thread actions (resolve / reopen / reply-only, each with its reply), in the conversation and ask: "Ready to post this review to GitHub? (yes / edit first / cancel)". Do NOT submit to GitHub yet.

13. **On user approval**, first re-check the PR is unchanged since phase 0:
    ```bash
    gh api repos/{owner}/{repo}/pulls/<number> --jq '{state, head_sha: .head.sha}'
    ```
    If `state` is now `closed`, stop and report — do not post. If `head_sha` differs from `<head-sha>`, new commits landed during the review: stop, tell the user which commits arrived, and ask whether to post against the reviewed commit anyway or re-run the review. Do not post silently.

    Then write the review JSON to a file made with `mktemp` (phase 0), `<review-json>` below, and submit it as one API call, removing the file whether or not the call succeeds:
    ```bash
    gh api repos/{owner}/{repo}/pulls/<number>/reviews --input <review-json>; rc=$?; rm -f <review-json>; exit $rc
    ```
    Use `"event": "COMMENT"` and `"commit_id": "<head-sha>"`, so inline comments anchor to the lines that were actually reviewed. If the call fails, fix the cause, write a fresh file and submit again.

    Then carry out the step 9 thread actions — the reply first, then the state change:
    ```bash
    gh api repos/{owner}/{repo}/pulls/<number>/comments/<comment databaseId>/replies -f body='<reply>'
    gh api graphql -f id=<thread id> -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }'
    ```
    For a reopen, use `unresolveReviewThread` in place of `resolveReviewThread`. For an outside-diff finding, post the verdict as a conversation comment instead — no state change follows:
    ```bash
    gh pr comment <number> --body '<verdict>'
    ```

14. **Report back:** review URL, findings count by severity, how many of them are unsure, which are merge-blocking, and threads resolved / reopened.

## rules

- Read `AGENTS.md` before reviewing.
- Review against the default branch only. Never read other open PRs or branches — not for spec IDs, not for conflicts. Those are settled by `/pre-merge` against the default branch as it stands when the PR merges.
- Fetch every linked issue and check the diff against its acceptance criteria — a `Closes #N` PR with unmet criteria is a finding.
- Verify every finding against source files — not just the diff. A finding you could not confirm is posted tagged **Unsure** with what was not verified — never dropped silently, never presented as confirmed.
- No praise and no "what's done well" — findings, fixes and gate results only.
- Check every round that changes production source for behaviour no spec states (step 6c), and raise each as a finding with the suggested spec and the reason it helps.
- On a follow-up round, seek new findings only in the commits since the last round, and judge previous threads from the code at `<head-sha>` — never from a fixer's reply or an earlier round's conclusion.
- The Verification section is mandatory — report every gate's real result, including gates that could not run and tests that skipped.
- Do not duplicate existing feedback — match by file and symptom, not line.
- Every finding row must link to its inline comment, or, for a finding outside the diff, to its permalink.
- Every severity section must have a batch "Prompt for AI" toggle.
- New findings go in one review, one API call; step 9 thread replies and state changes follow it.
- Never resolve or reopen a thread without replying first.
- Always present findings in the conversation and wait for explicit approval before posting to GitHub, unless the invocation explicitly says to post directly (e.g. "review and post" or "--post").
- After posting, remind the developer they can use `/fix-pr-findings` to address findings.
