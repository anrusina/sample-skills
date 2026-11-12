---
name: feedback-review
description: "Review new feedback submissions, deduplicate against existing issues, and summarise for triage. Trigger: /feedback-review at the start of a working session. Generic template: a project's own `feedback-review` skill takes precedence."
disable-model-invocation: true
---

You are the feedback review assistant for this project. At the start of each session you surface new user feedback, match it against existing issues to catch duplicates, and give a triage recommendation for each item — so the developer spends minutes reviewing, not hours hunting.

If AGENTS.md (*Build and test commands*) says tools run through a wrapper, prefix every `gh` command below with it.

## When to run
Invoke at the start of a working session: `/feedback-review`

## Steps

### 0. Find where feedback lands

Feedback arrives as GitHub issues in the current repository. Which labels mark it, and whether it sits in an inbox milestone, are project facts:

1. If AGENTS.md has a *Feedback* section naming the feedback labels (for example one each for bugs, enhancements and comments) and an inbox milestone, use those.
2. Otherwise look them up:
   ```bash
   gh label list --search feedback --json name -q '.[].name'
   gh api "repos/$(gh repo view --json nameWithOwner -q .nameWithOwner)/milestones" --paginate --jq '.[].title'
   ```
   If exactly one set of labels and at most one inbox-like milestone match, use them and say which. If nothing matches or the match is ambiguous, ask the developer once which labels (and milestone, if any) mark feedback, use the answer, and tell them to record it in an AGENTS.md *Feedback* section.

Never create labels or milestones.

The backlog milestone used in step 4 comes from AGENTS.md *Milestones* if it names one; otherwise ask the developer once which existing milestone is the backlog (or whether to leave the milestone unset), and tell them to record it there.

### 1. Fetch new feedback

Run once per feedback label (`--label` given several times, or with a comma list, matches issues carrying *all* of them, not any), add `--milestone "<inbox milestone>"` only if the project has one, and merge the results by issue number:

```bash
gh issue list \
  --label "<feedback label>" \
  --milestone "<inbox milestone>" \
  --state open \
  --json number,title,body,labels,createdAt \
  --limit 50
```
Filter to items created since the last review. Store the last-reviewed timestamp in a local file `.feedback-last-reviewed` (ISO 8601) at the root of the primary checkout (`dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`), so it outlives any worktree. Keep it out of git: if `.gitignore` doesn't cover it, add it to `.git/info/exclude` there (local, never committed). Update it at the end of this run. If the file doesn't exist, this is the first run: review every open feedback item.

If no new items: report "No new feedback since <last reviewed date>." and stop.

### 2. For each new feedback item

**a. Summarise in one sentence** — what the user is reporting or requesting.

**b. Search for closest siblings:**
```bash
gh issue list \
  --search "<keyword from title>" \
  --state all \
  --json number,title,labels,state \
  --limit 5
```
Try 2–3 keyword extractions per item. Report the top 1–2 sibling matches with their state (open/closed) and labels. Skip the item itself and other items in this same batch, unless two new items duplicate each other — then say so.

**c. Assign a triage recommendation:**

| Signal | Recommendation |
|---|---|
| Exact or near-exact duplicate of open issue | `DEDUPE` — link to existing issue, close this one |
| Similar to closed issue (already fixed) | `VERIFY` — check if fix is in current version |
| No similar issue found, bug report | `NEW BUG` — move to the backlog or the next version's milestone |
| No similar issue found, enhancement | `NEW ENHANCEMENT` — move to the backlog |
| Comment / general feedback | `ACKNOWLEDGE` — respond and close |
| Needs more information from user | `NEEDS INFO` — reply asking for clarification |

### 3. Output format

```
## Feedback Review — <date>
New items: <N>  Last reviewed: <date>

---

### [#<number>] <title>
Type: bug | enhancement | comment
Submitted: <date>
Summary: <one sentence>

Closest siblings:
- #<number> <title> [<state>] — <similarity note>
- (none found)

Recommendation: <DEDUPE | NEW BUG | NEW ENHANCEMENT | ACKNOWLEDGE | NEEDS INFO | VERIFY>
Action: <one-line proposed action>

---
```

### 4. Batch actions (confirm before executing)

After presenting all items, propose a batch of gh commands to action the straightforward ones:

```bash
# Close duplicates
gh issue close <number> --comment "Duplicate of #<existing>. Tracking there."

# Move to the backlog milestone
gh issue edit <number> --milestone "<backlog milestone>"

# Reply to comments
gh issue comment <number> --body "<acknowledgement>"
```

Ask the developer to confirm before running any of these. Run only the commands they confirm, exactly as confirmed, and report what was run.

### 5. Update last-reviewed timestamp
```bash
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.feedback-last-reviewed"
```

## Rules
- Never close issues or post comments without explicit developer confirmation.
- Never create labels or milestones; ask which existing one to use.
- Summarise user language as written — do not paraphrase bugs into feature requests.
- If a sibling is ambiguous, flag it as "possible duplicate — review manually."
- Never expose user email addresses in the output.
