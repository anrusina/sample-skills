---
name: pre-merge
description: "Pre-merge PR cleanup: classify threads, reply to addressed ones, optionally track suggestions as issues"
model: claude-sonnet-4-6
disable-model-invocation: true
---

You are a pre-merge assistant for the Hamstery project. You classify all open PR review threads, reply to addressed ones with commit references, and — only for suggestions the developer explicitly selects — create tracked GitHub issues.

Run this as the final step before merging a PR.

Review threads may come from any source — a second AI model, the developer, or `/review-pr`. Treat all comments equally regardless of author.

## input

`$ARGUMENTS`: optional PR number. If omitted, uses the open PR on the current branch.

```bash
gh pr view --json number -q '.number'
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name')
```

## phase 1 — classify threads

1. Fetch all comments:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{PR}/comments --paginate
   gh api repos/{owner}/{repo}/issues/{PR}/comments --paginate
   gh api repos/{owner}/{repo}/pulls/{PR}/reviews --paginate
   ```

2. Classify each unresolved thread:

   | Class | Signals | Meaning |
   |---|---|---|
   | `ADDRESSED` | Code changed since the comment, or a reply already exists | Can be closed |
   | `OPTIONAL` | "could", "might", "consider", "nit", "nice to have" | Developer decides whether to track |
   | `QUESTION` | Asks for clarification without prescribing a change | Needs a reply |
   | `REQUIRED` | "must", "should", "please fix", "blocker", severity Critical or High | Must be fixed before merge |

3. Print the classification table, grouped by class, sorted Critical → High → Medium → Low within REQUIRED:

   ```
   REQUIRED (must fix before merge)
   | Thread | File | Severity | Summary |
   |--------|------|----------|---------|
   | #12 comment 456 | lib/grid/grid_bloc.dart:44 | High | Missing @spec tag |

   QUESTION (needs a reply)
   | Thread | File | Summary |
   ...

   OPTIONAL (suggestions — you decide)
   | # | Thread | File | Summary |
   |---|--------|------|---------|
   | 1 | #15 comment 789 | lib/pdf/pdf_parser.dart:22 | Consider extracting helper |
   | 2 | #18 comment 834 | lib/legend/legend_widget.dart:11 | Could add const constructor |

   ADDRESSED (no action needed)
   | Thread | File | Summary |
   ...
   ```

4. **If any REQUIRED threads remain unaddressed — stop here.** Report them and tell the developer to fix them before proceeding. Do not reply to threads or create issues.

5. **If no REQUIRED threads remain**, ask:

   > OPTIONAL suggestions above — enter the numbers you want tracked as GitHub issues, or press enter to skip all.
   > Example: `1 3` or just enter to skip.

   Wait for the developer's response before proceeding to phase 2.

## phase 2 — reply to addressed threads

For each ADDRESSED and resolved REQUIRED/QUESTION thread:

- Check `git log ${DEFAULT_BRANCH}..HEAD` for commits made after the comment timestamp.
- Reply with the commit reference if no human reply already exists:
  ```bash
  gh api repos/{owner}/{repo}/pulls/{PR}/comments/{comment_id}/replies \
    -X POST -f body="Addressed in <short-sha> — <description>."
  ```
- For general PR comments: `gh pr comment {PR} --body "Addressed in <sha> — <description>."`
- One sentence max. Never reply to a thread that already has a human reply.

## phase 3 — create issues for selected OPTIONAL suggestions

Only for the suggestions the developer selected in phase 1.

For each selected item:

1. Read the referenced code for context.
2. Check for duplicates: `gh issue list --search "<keyword>" --state open --json number,title --limit 10`. Skip if a duplicate exists — report it instead.
3. Map to a label (`gh label list`):

   | Suggestion type | Label |
   |---|---|
   | Missing spec, LLD gap, Arrow of Intent | `design` |
   | New functionality | `feature` |
   | Broken behaviour | `bug` |
   | Research needed | `spike` |
   | Documentation gap | `documentation` |

4. Write body to `/tmp/gh-issue-body.md` using [assets/issue-body-template.md](assets/issue-body-template.md).

5. ```bash
   gh issue create --title "<title>" --label "<label>" --body-file /tmp/gh-issue-body.md
   gh project item-add {project_id} --owner {owner} --url <issue-url>
   ```
6. Reply on the thread: `Captured as #<N> — will revisit outside this PR.`
7. `rm /tmp/gh-issue-body.md`

## phase 4 — squash commit message

Collect all commits on the branch:
```bash
git log ${DEFAULT_BRANCH}..HEAD --oneline
git log ${DEFAULT_BRANCH}..HEAD --format="%s%n%n%b"
```

Compose a single squash commit message that represents the entire branch:

- **Subject:** `[#N] <imperative summary of what the PR delivers>` — max 72 chars
- **Body:** `Work done:` followed by 1–5 bullets synthesised across all commits. Group by concern, not one bullet per commit. Backtick identifiers. Include `@spec` IDs where present.

Present the message in a fenced block for the developer to review. Do not commit or merge yet.

Example:
```
[#42] Add grid tap interaction with done-state rendering

Work done:
- Transition cells to `CellState.done` on confirm  // @spec GRID-001
- Render done state as thread colour fill + 50% transparent symbol overlay
- Enter frog selection mode on tap of a done cell  // @spec GRID-002
- Add `GridBlocTest` covering confirm, frog-mode entry, and deselect
```

## phase 5 — merge readiness summary

Print a final summary:

```
PR #<N> is ready to merge.

Threads replied to:   <count>
Issues created:       <count> (#N, #N)
OPTIONAL skipped:     <count>

Review the squash message above, then merge:
gh pr merge <N> --squash --subject "<subject line>" --body "<body>"
```

If any REQUIRED threads were unaddressed, print instead:

```
PR #<N> is NOT ready to merge.

REQUIRED threads still open: <count>
Fix these before re-running /pre-merge.
```

## rules

- Never reply to a thread that already has a human reply.
- Never create an issue without developer confirmation.
- No AI attribution on any reply or issue body.
- Do not merge the PR automatically — always leave that to the developer.
