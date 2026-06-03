# Review summary format

Use this structure for the overall review summary comment body.

---

## Code Review — PR #<number>: <title>

**Branch:** `<head>` → `<base>`
**Scope:** +<additions> / -<deletions> across <file count> files, <commit count> commits

<1-2 sentence overview of what the PR does.>

---

### What's in the PR
<Bulleted list of major components or features changed.>

---

### What's done well
<4-8 specific positive observations.>

---

### Findings

<details>
<summary><strong><Severity> (<count>)</strong> — <one-line policy></summary>

| # | Finding | File | Description |
|---|---|---|---|
| N | [<Title>](<inline comment URL>) | `<filename>` | <one-line description> |

<details>
<summary><strong>Prompt for AI — fix all <count> <severity> findings</strong></summary>

/fix-pr-findings <url1>
/fix-pr-findings <url2>
Run flutter test after all changes.

</details>
</details>

---

<Closing: which items block merge, which can be follow-up issues.>
