# Inline comment format

Use this structure for each inline comment body.

---

**[<Severity>] <Title>** — for an unsure finding: **[Unsure · <Severity>] <Title>**

<2-4 sentences describing the problem and its impact.>

**Unverified:** <Unsure findings only — one line on what could not be confirmed in the source, so the reader knows what to check first. Omit this line for confirmed findings.>

**Suggestion:** <Concrete fix with a code snippet in the project's language if applicable.>

**Blast radius:** <emoji> <level> — <one sentence on what could break.>

**Fix in:** This PR — or — Follow-up issue: <reason (undecided product/design question, another subsystem or issue #N, or too big for this PR — say why)>; suggested title "<title>".

---

<details>
<summary><strong>Prompt for AI</strong></summary>

/fix-pr-findings
<Step-by-step fix instructions referencing exact file paths, line numbers, and what to change. End with "Run the project's quality gates after changes.">

</details>

---

## Unspecced-behaviour variant (step 6c)

Use this structure instead for a finding from the step 6c check: behaviour the code has and no EARS spec states. The labelled lines replace the free description, so every such finding reaches `/fix-pr-findings` in the same shape.

---

**[<Severity>] <Title>** — for an unsure finding: **[Unsure · <Severity>] <Title>**

**The behaviour:** <What the code does, with file and line. Say which spec and LLD text come closest and what they leave unsaid.>

**Why speccing it helps:** <What could change or regress unnoticed without it, or what a later reader or reviewer could not tell is intended.>

**Test status:** <Whether a test already exercises the behaviour, in which file and under which `@spec` tag — or "untested".>

**Unverified:** <Unsure findings only — one line on what could not be confirmed in the source. Omit this line for confirmed findings.>

**Suggestion:** <"Docs only, LLD first" when no code or test changes; otherwise say what else is needed.>
- **LLD sentence:** <The LLD file and section that must state the behaviour first, and what the sentence says.>
- **Spec:** <The EARS text written out with a suggested ID — the next free one in the subsystem's namespace on the default branch — or the reworded text of an existing spec, keeping its ID.>
- **Test:** <The test to add and its `@spec` tag. Omit this line when a test already covers the behaviour.>

**Blast radius:** <emoji> <level> — <one sentence on what could break.>

**Fix in:** This PR — or — Follow-up issue: <reason>; suggested title "<title>".

---

<details>
<summary><strong>Prompt for AI</strong></summary>

/fix-pr-findings
<Step-by-step instructions, docs before tests: the LLD file, section and sentence; the EARS file and spec text; the test file and tag if one is needed. End with "Run the project's quality gates after changes.", or, when every change is Markdown, "Markdown only, so the quality gates do not apply.">

</details>

---

## Blast radius levels

| Blast radius | Emoji | When |
|---|---|---|
| Isolated | ✅ | Single component, single test, config constant |
| Localised | 🔵 | Private method, one state holder or service, one screen |
| Cross-cutting | ⚠️ | A state-holder or service interface change, shared state, spec update |
| Systemic | 🔴 | Storage schema, navigation model, a core domain model the HLD names, a parser or service interface many subsystems depend on |
