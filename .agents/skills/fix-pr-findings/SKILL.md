---
name: fix-pr-findings
description: "Orchestrate fixes for PR review findings via sub-agents, run one after another. Trigger: /fix-pr-findings <N>, or a request to address a PR's review findings, including one relayed by a coordinator session. Generic template: a project's own `fix-pr-findings` skill takes precedence."
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/scripts/review-threads.sh *)
---

Orchestrate fixes for GitHub PR review findings. Fetches review comments, presents findings for selection, and spawns sub-agents to apply each fix in isolation with properly formatted commits.

Findings may come from any reviewer — a second AI model, the developer, or `/review-pr`.

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
| wrapper | AGENTS.md build section: the prefix the toolchain runs through (a version manager's exec command, for example), or none. Run the gates, and each tool the wrapper provides (the tools its config file lists), through it; pass it to this skill's scripts as `--wrap '<wrapper>'`; run every other command bare, so it matches `allowed-tools` |
| gates | AGENTS.md build section: the format, lint/analyze and test commands, in order, or the one command that runs them all |
| format fix | AGENTS.md build section: the write-mode formatter, if the format gate only checks |
| build-input docs | AGENTS.md *Project structure*: Markdown the build reads, or none. Whatever AGENTS.md says, Markdown or MDX inside the source tree that the build reads (content collections, MDX pages, a docs site's sources) counts too. A change to any of it runs the gates like code |
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

Pass the wrapper on to every sub-agent, with the row's rule.

A **documentation-only fix** is one whose changed files are all Markdown or under `docs/`, and none of them under a *build-input docs* path: Markdown the build reads is a build input, so a fix to it runs the gates like code.

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

   Top-level review bodies and conversation comments (`--comments` and `--json` cannot be combined; `--json comments` already includes them):
   ```bash
   gh pr view <number> --json comments,reviews
   ```

   Unresolved inline review threads, one JSON object each (resolved threads are already handled and are skipped):
   ```bash
   ${CLAUDE_SKILL_DIR}/scripts/review-threads.sh --wrap '<wrapper>' <number>
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

   **Stop here until the developer answers.** Triage is the whole of this turn; no sub-agent starts before the selection.

## phase 2 — fix via sub-agents

5. **Check out the PR's branch, up to date.** Every sub-agent commits and pushes from this checkout, so it has to be the PR's head branch at the remote's tip, with nothing uncommitted:
   ```bash
   gh pr view <number> --json headRefName -q .headRefName
   git branch --show-current
   git fetch origin
   git status --short --branch
   ```
   If the current branch is not the PR's head branch, or the tree has uncommitted changes, stop and say so: fixes committed here would land on the wrong branch, or carry someone else's work. If the branch is only behind `origin/<head>`, `git pull --ff-only`; if it has diverged, stop and report.

6. For each selected finding (or tightly coupled group of findings), spawn a sub-agent, **one after another**: start the next only when the previous one has reported back. Every sub-agent commits and pushes from the same checkout, so two at once would collide on git's index lock, commit each other's staged files, and race on the push. Order them so a finding that another depends on goes first.

7. **Sub-agent prompt:** load [assets/subagent-prompt.md](assets/subagent-prompt.md) and substitute all `<...>` placeholders with the finding's specific values before spawning, including the *Fix* section of each loaded asset.

   If a sub-agent reports a failure (a gate it cannot make pass, a rejected push), stop the remaining fixes and report: the next fix would build on a branch in an unknown state.

## phase 3 — report

8. **Reply on each fixed thread — never resolve it.** Resolving is the next `/review-pr`'s call, once it has verified the fix:
   ```bash
   gh api repos/{owner}/{repo}/pulls/<number>/comments/<first comment databaseId>/replies -f body='Addressed in <short-sha> — <what changed>.'
   ```
   `gh` fills `{owner}` and `{repo}` itself from the current checkout. An outside-diff finding has no thread — post a PR conversation comment instead:
   ```bash
   gh pr comment <number> --body 'Addressed in <short-sha> — outside-diff finding #<N>: <what changed>.'
   ```

8b. **Track each deferred finding the developer agreed to defer.** If an open issue covers it, reply `Tracked in #<N> — <reason it can't be fixed here>.`; otherwise create the proposed issue (as `/pre-merge` does for its follow-up items — labels and milestone chosen from those that exist on GitHub, never new ones) and reply `Captured as #<N> — <reason it can't be fixed here>.` — on the thread, or in a PR comment for an outside-diff finding. Never resolve the thread: the next `/review-pr` resolves it once it has checked that the issue covers whatever this PR leaves unfixed. When part of a finding is fixed here, say which part in the reply, and make the issue cover the rest.

9. After all agents complete:
   - Table of findings fixed with commit hashes, and deferred findings with their issue numbers
   - Any findings that failed with the reason
   - Reminder to run the project's quality gates (the *gates* fact) — unless every fix was documentation-only, in which case state that the gates were skipped because those files cannot affect them
   - Anything the *Report* section of a loaded asset adds

## commit format

[assets/commit-format.md](assets/commit-format.md); the sub-agent prompt carries it pasted in.

## rules

- Never fix on the reviewer's say-so alone: verify every finding against the source and present the triage first. A reviewer can be wrong, out of scope, or contradicted by an upstream doc.
- Every fix is a new commit on top of the branch, never an amend: reviewers re-check each fix by its commit, and a rewritten history breaks their citations.
- If there are no gates, ask the developer once for the commands, use them, and tell them to record them in AGENTS.md's build section.
