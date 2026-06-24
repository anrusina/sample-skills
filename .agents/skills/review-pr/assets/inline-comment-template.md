# Inline comment format

Use this structure for each inline comment body.

---

**[<Severity>] <Title>**

<2-4 sentences describing the problem and its impact.>

**Suggestion:** <Concrete fix with code snippet if applicable.>

**Blast radius:** <emoji> <level> — <one sentence on what could break.>

---

<details>
<summary><strong>Prompt for AI</strong></summary>

/fix-pr-findings
<Step-by-step fix instructions referencing exact file paths, line numbers, and what to change. End with "Run quality gates after changes.">

</details>

---

## Blast radius levels

| Blast radius | Emoji | When |
|---|---|---|
| Isolated | ✅ | Single component, single test, config constant |
| Localised | 🔵 | Private method, one service/BLoC, one screen |
| Cross-cutting | ⚠️ | Interface change, shared state, spec update |
| Systemic | 🔴 | Storage schema, navigation model, shared domain entity, core service interface |

For framework-specific blast radius examples, see [flutter/review-categories.md](flutter/review-categories.md).
<!-- TODO: replace with your framework's blast radius guidance -->
