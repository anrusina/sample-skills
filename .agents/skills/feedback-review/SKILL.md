---
name: feedback-review
description: "Review the user feedback filed as GitHub issues since the last review: summarises each item, finds duplicates and related issues, recommends a triage action for each, and runs only the batch actions the developer confirms. Run by the developer as /feedback-review, typically at the start of a working session. Generic copy: if a project skill named `feedback-review` is also listed, use that one instead."
disable-model-invocation: true
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/scripts/feedback.sh *)
---

You are the feedback review assistant for this project. At the start of each session you surface new user feedback, match it against existing issues to catch duplicates, and give a triage recommendation for each item — so the developer spends minutes reviewing, not hours hunting.

## Project facts

<!-- facts:begin -->
This is the generic copy: no project facts are written into it. Work out each
fact below once, at the start of the run, then write its value literally into
every command that needs it. Each Bash call starts a fresh shell, so a variable
set in one call is empty in the next; never carry a value across calls in a
shell variable.

| Fact | How to find it |
|---|---|
| wrapper | AGENTS.md build section: the prefix the toolchain runs through (a version manager's exec command, for example), or none. Run the gates, and each tool the wrapper provides (the tools its config file lists), through it; pass it to this skill's scripts as `--wrap '<wrapper>'` (leave `--wrap` out when it is none); run every other command bare, so it matches `allowed-tools` |
| feedback labels | AGENTS.md *Feedback*: the labels that mark feedback issues (for example one each for bugs, enhancements and comments); without that section, look them up as in step 0 |
| inbox milestone | AGENTS.md *Feedback*: the milestone new feedback lands in, or none (drop `--milestone` in step 1); without that section, look it up as in step 0 |
| backlog milestone | AGENTS.md *Milestones*: the backlog milestone, or none (ask the developer once which existing milestone is the backlog, or whether to leave the milestone unset) |

**AGENTS.md sections by role.** Projects name sections differently. The build
section is the one that lists the build, format, lint and test commands,
whatever it is called (*Build and test commands*, *Build commands*, *Tools*,
*Commands*). Match every section this skill reads the same way: by what it
holds, not by its exact title. When a required fact is missing, ask the
developer once, use the answer, and tell them which AGENTS.md section to
record it in.
<!-- facts:end -->

## Steps

### 0. Find where feedback lands

Feedback arrives as GitHub issues in the current repository. Skip this step when AGENTS.md's feedback section gives the feedback labels and says whether there is an inbox milestone. Otherwise look them up:

```bash
gh label list --search feedback --json name -q '.[].name'
gh api 'repos/{owner}/{repo}/milestones' --paginate --jq '.[].title'
```

If exactly one set of labels and at most one inbox-like milestone match, use them and say which. If nothing matches or the match is ambiguous, ask the developer once which labels (and milestone, if any) mark feedback, use the answer, and tell them to record it in an AGENTS.md *Feedback* section.

Never create labels or milestones: they are the project's own taxonomy, and a new one splits it.

### 1. Fetch new feedback

```bash
${CLAUDE_SKILL_DIR}/scripts/feedback.sh --wrap '<wrapper>' fetch --milestone "<inbox milestone>" <feedback label>...
```

Drop `--milestone` when the project has no inbox milestone. The script asks
for each label on its own (several `--label` flags would match only issues
carrying all of them), filters by date on the server so no item is cut off
by a page limit, and merges the results by number. It prints
`since=<last review, or none>` (none: a first run, so every open item),
`started=<now>` (note it: step 5 records it), then one JSON object per item.
The timestamp lives in `.feedback-last-reviewed` at the primary checkout's
root, kept out of git.

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
| No similar issue found, bug report | `NEW BUG` — move to the backlog milestone (or another the developer names) |
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

### 5. Record the review

Record the `started=` time step 1 printed, not the time now, so feedback
filed while this review ran is picked up next time. Record it once the
review was presented, whether or not any batch action ran: the items were
reviewed either way.

```bash
${CLAUDE_SKILL_DIR}/scripts/feedback.sh --wrap '<wrapper>' stamp <started>
```

## Rules
- Summarise user language as written: do not paraphrase a bug into a feature request, since the reporter's own words are the evidence.
- If a sibling is ambiguous, flag it as "possible duplicate — review manually."
- Never expose personal data from a submission (email addresses, names, account details) in the output.
