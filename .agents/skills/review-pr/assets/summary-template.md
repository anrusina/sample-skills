# Review summary format

Use the full structure below for a full review, and the *Follow-up round* variant at the end for a follow-up round. Both end with the `review-pr: reviewed` marker — the next round finds the last reviewed commit from it, so never omit it. `/fix-pr-findings` is written in the form the *skill names* fact gives.

---

## Code Review — PR #<number>: <title>

**Branch:** `<head>` → `<base>`
**Scope:** +<additions> / -<deletions> across <file count> files, <commit count> commits

<1-2 sentence overview of what the PR does.>

---

### What's in the PR
<Bulleted list of major components or features changed.>

---

### Verification

<Filled from the phase 0 gate run, in the review worktree after the fresh-checkout setup. One row per gate.>

| Gate | Result |
|---|---|
| <each command in the *gates* fact, in order, as AGENTS.md's build section names it — e.g. format, lint/analyze, test; one row per step when a single command runs several> | <pass / N files would change / N issues / N passed, N failed, N skipped> |
| <each guard script `AGENTS.md` lists, if any> | <pass / N violations> |
| <each row the *Verification* section of a loaded asset adds — a manual check, a budget table, a registry check> | <what was done and its result, or "not run" with the reason> |

<Name any tests that skipped (for missing fixtures, for example) and say what that leaves unverified. If a gate could not be run, say so here rather than omitting the row — a missing row reads as a gate that passed.>

**Checked:** <the step 6 categories applied — code, or documentation on the fast path — whether the unspecced-behaviour check (step 6c) ran and which existing specs it found behaviours to be limit cases of, and whether the `--deep` lenses ran, so "no findings" says what it covers.>

---

### Findings

<details>
<summary><strong><Severity> (<count>)</strong> — <one-line policy></summary>

| # | Finding | File | Description | Fix in |
|---|---|---|---|---|
| N | [<Title>](<inline comment URL>) | `<filename>` | <one-line description> | This PR / Follow-up: <reason> |

<Unsure findings stay in their severity's table, title prefixed `Unsure ·`, so severity counts include them. A finding outside the diff stays in its severity's table too, linked to its permalink instead of an inline comment.>

<details>
<summary><strong>Prompt for AI — fix all <count> <severity> findings</strong></summary>

/fix-pr-findings <url1>
/fix-pr-findings <url2>
/fix-pr-findings PR #<number>, outside-diff finding #<N>   ← for a finding with no inline comment
Run the project's quality gates after all changes.   ← plus any closing line a loaded asset's *Inline comments* section adds

</details>
</details>

---

### Outside the diff

<Omit this section when empty. One block per finding whose line falls outside every diff hunk, in the inline comment format, headed by its finding number and permalink (`https://github.com/<repo>/blob/<head-sha>/<path>#L<start>-L<end>`, with `<repo>` written in).>

---

<Closing: how many findings are to be fixed in this PR, and each follow-up with its reason and suggested issue title. Every finding is one or the other — none is optional.>

<!-- review-pr: reviewed <full 40-char head-sha> -->

---

## Follow-up round variant

A follow-up round reports only what changed since the last round. Findings and *Outside the diff* sections use the same format as above, holding only this round's new items; omit any that are empty.

---

## Code Review — PR #<number>, round <N>

**Since:** `<last-sha short>` → `<head-sha short>` (<commit count> commits)

**Previous threads:** <X> verified fixed · <T> verified tracked · <Y> reopened · <Z> still open · <W> replied, left for the developer

| Gate | Result |
|---|---|
| <each command in the *gates* fact, in order, as AGENTS.md's build section names it — e.g. format, lint/analyze, test> | <pass / N files would change / N issues / N passed, N failed, N skipped> |
| <each guard script `AGENTS.md` lists, if any> | <pass / N violations> |
| <each row the *Verification* section of a loaded asset adds> | <what was done and its result, or "not run" with the reason> |

<Skipped tests and gates that could not run, as in the full template.>

**Checked:** <the step 6 categories applied to the range, plus the weakened-test check and the unspecced-behaviour check (step 6c).>

### New findings (<count>)

<Severity-grouped tables with Prompt for AI toggles, as in the full template — or "None." when the range is clean.>

<Closing: what still blocks merge, counting threads still open from earlier rounds. Threads verified as tracked are neither still open nor blocking.>

<!-- review-pr: reviewed <full 40-char head-sha> -->
