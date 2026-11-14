# Inline comment format

Use this structure for each inline comment body. Apply the *Inline comments* section of each loaded asset: the stack asset names the snippet language, and a field asset may add a closing line for the prompt or blast-radius examples.

`/fix-pr-findings` below is written in the form the *skill names* fact gives.

---

**[<Severity>] <Title>** — for an unsure finding: **[Unsure · <Severity>] <Title>**

<2-4 sentences describing the problem and its impact.>

**Unverified:** <Unsure findings only — one line on what could not be confirmed in the source, so the reader knows what to check first. Omit this line for confirmed findings.>

**Suggestion:** <Concrete fix with a code snippet in the project's language (the loaded stack asset names it), if applicable.>

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

If the *blast-radius map* fact names a section of `AGENTS.md` that maps the project's parts to these levels, classify by it. Otherwise use the generic definitions below, with any examples a loaded field asset adds.

| Blast radius | Emoji | When |
|---|---|---|
| Isolated | ✅ | One file, one component used in one place, one test, one config constant, one doc line |
| Localised | 🔵 | A private method, one module, one state holder or service, one screen or page |
| Cross-cutting | ⚠️ | An interface several modules call, shared state, a shared component or the design tokens, a spec update |
| Systemic | 🔴 | Stored data and its schema, the navigation or routing model, a core domain model the HLD names, an interface many subsystems depend on, an identifier or format published outside the project, build or release configuration |
