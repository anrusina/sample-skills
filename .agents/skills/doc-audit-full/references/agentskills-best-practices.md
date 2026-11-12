# Agent Skills best practices — audit checklist

Source: https://agentskills.io/skill-creation/best-practices

Use this checklist to evaluate each file in `.agents/skills/<name>/SKILL.md`.
Report findings as **Bloat**, **Scope**, **Calibration**, **Structure**, or **Frontmatter**.

---

## 1. Size gate

- SKILL.md should stay under **500 lines / ~5,000 tokens**.
- If over: flag for progressive disclosure refactor (move reference material to `references/`, output templates to `assets/`).

---

## 2. Context efficiency (Bloat)

Flag prose that explains things the agent already knows from training — general concepts, standard library behaviour, widely-known protocols. These add tokens without adding value.

**Examples of bloat:**
- Explaining what a PDF is, how HTTP works, what a database migration does
- Generic advice: "handle errors appropriately", "follow best practices for X"
- Restating what the task produces rather than how to approach it

**Signal:** "Would the agent get this wrong without this instruction?" If no → cut.

---

## 3. Scope coherence (Scope)

A skill should encapsulate **one coherent unit of work**.

- Too narrow → multiple skills must load for a single task (overhead, conflicting instructions)
- Too broad → hard to trigger precisely, agent struggles to extract what's relevant

Flag skills that appear to cover unrelated concerns in the same file.

---

## 4. Instruction calibration (Calibration)

**Where the task tolerates variation:** instructions should explain *why*, not prescribe rigid steps. The agent makes better context-dependent decisions when it understands the purpose.

**Where operations are fragile or consistency matters:** be explicit and prescriptive. Provide exact commands; say "do not modify the command or add flags."

**Defaults vs menus:** when multiple tools could work, the skill should pick a default and mention alternatives briefly. Flag skills that present 3+ equivalent options without a clear recommendation.

**Procedures over declarations:** a skill should teach *how to approach* a class of problems, not describe *what to produce* for one specific instance. Flag skills that read like a specification for a single output rather than a reusable method.

---

## 5. Structure patterns (Structure)

Check for these high-value patterns. Missing patterns are not always gaps — only flag when the task would benefit from them.

| Pattern | When valuable | Flag if missing |
|---|---|---|
| **Gotchas section** | Non-obvious environment-specific facts that defy reasonable assumptions | Yes, if the skill has domain-specific traps a new agent would walk into |
| **Output templates** | Agent must produce output in a specific format | Yes — templates in `assets/` (conditional load) are more reliable than prose descriptions |
| **Checklists** | Multi-step workflow with dependencies or validation gates | Yes, if steps have ordering requirements and no checklist exists |
| **Validation loop** | Destructive or batch operations | Flag if plan-validate-execute pattern is absent for risky operations |

**Progressive disclosure:** large reference content should live in `references/` with an explicit load condition (`"load references/X.md if [condition]"`). A generic "see references/" pointer without a condition is a flag — the agent needs to know *when* to load it.

---

## 6. Frontmatter completeness (Frontmatter)

| Field | Required | Notes |
|---|---|---|
| `name` | Yes | Matches directory name |
| `description` | Yes | Trigger-phrased for auto-invokable skills ("Use when..."). Clear enough to match real user prompts. |
| `model` | Routine skills only | See model calibration below |
| `disable-model-invocation` | As recorded | Must match the project's invocation-gating table, if it records one — look in `AGENTS.md`, then `docs/dev/skills.md`, for a table listing which skills are gated. A skill there marked open carries an explicit-request check in its body instead; flag any skill whose flag differs from the table, but never add or remove the flag to fix it. A new side-effect skill (creates PRs, opens issues, pushes commits, modifies shared state) is gated unless its body has an explicit-request check, and gets a row in that table. When the project records no gating table, skip the comparison and say so in the report |
| `allowed-tools` | Recommended | List specific `Bash(pattern *)` entries to reduce permission prompts |

**Model calibration:**

| `model` | Use for |
|---|---|
| `claude-haiku-4-5-20251001` | Routine, well-defined tasks: commit messages, issue creation, label lookup |
| *(omitted)* | Everything requiring reasoning, synthesis, or cross-file analysis: code review, doc repair, design docs. The skill runs on the session's default model, so it improves as the default does instead of staying pinned to an older one. |

Flag any non-haiku `model` pin as stale — judgment skills omit the field.
Flag `claude-haiku-4-5-20251001` on skills that require non-obvious judgment or cross-file synthesis as under-powered.
Flag a routine mechanical skill with no `model` as over-powered — it should pin haiku.
