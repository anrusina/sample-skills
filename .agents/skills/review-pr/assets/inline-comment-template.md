# Inline comment format

Use this structure for each inline comment body.

---

**[<Severity>] <Title>**

<2-4 sentences describing the problem and its impact.>

**Suggestion:** <Concrete fix with Dart code snippet if applicable.>

**Blast radius:** <emoji> <level> — <one sentence on what could break.>

---

<details>
<summary><strong>Prompt for AI</strong></summary>

/fix-pr-findings
<Step-by-step fix instructions referencing exact file paths, line numbers, and what to change. End with "Run flutter test after changes.">

</details>

---

## Blast radius levels

| Blast radius | Emoji | When |
|---|---|---|
| Isolated | ✅ | Single widget, single test, config constant |
| Localised | 🔵 | Private method, one BLoC, one screen |
| Cross-cutting | ⚠️ | BLoC event/state interface change, shared state, spec update |
| Systemic | 🔴 | Storage schema, navigation model, `CellState` model, PDF parser |
