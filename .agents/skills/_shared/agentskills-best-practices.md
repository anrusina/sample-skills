# Agent Skills best practices — audit checklist

Source: https://agentskills.io/skill-creation/best-practices

Evaluate each `.agents/skills/<name>/SKILL.md` against this checklist.
Report findings as **Bloat**, **Scope**, **Calibration**, **Structure**, **Frontmatter** or **Stale**.

---

## 1. Size gate

- SKILL.md should stay under **500 lines / ~5,000 tokens**.
- If over: flag for progressive disclosure refactor (move reference material to `references/`, output templates to `assets/`).

---

## 2. Context efficiency (Bloat)

Flag prose that explains what the agent already knows — general concepts, standard library behaviour, widely-known protocols — and generic advice ("handle errors appropriately", "follow best practices for X").

**Signal:** "Would the agent get this wrong without this instruction?" If no → cut.

---

## 3. Scope coherence (Scope)

A skill should encapsulate **one coherent unit of work**.

- Too narrow → multiple skills must load for a single task
- Too broad → hard to trigger precisely

Flag skills that appear to cover unrelated concerns in the same file.

---

## 4. Instruction calibration (Calibration)

**Where the task tolerates variation:** explain *why* rather than prescribe rigid steps.

**Where operations are fragile or consistency matters:** be prescriptive. Give exact commands; say "do not modify the command or add flags."

**Defaults vs menus:** pick a default and mention alternatives briefly. Flag 3+ equivalent options with no clear recommendation.

**Procedures over declarations:** teach *how to approach* a class of problems. Flag skills that read like a specification for a single output rather than a reusable method.

---

## 5. Structure patterns (Structure)

Flag a missing pattern only when the task would benefit from it.

| Pattern | When valuable | Flag if missing |
|---|---|---|
| **Gotchas section** | Non-obvious environment-specific facts that defy reasonable assumptions | Yes, if the skill has domain-specific traps a new agent would walk into |
| **Output templates** | Agent must produce output in a specific format | Yes — templates in `assets/` (conditional load) are more reliable than prose descriptions |
| **Checklists** | Multi-step workflow with dependencies or validation gates | Yes, if steps have ordering requirements and no checklist exists |
| **Validation loop** | Destructive or batch operations | Flag if plan-validate-execute pattern is absent for risky operations |

**Progressive disclosure:** large reference content lives in `references/` with an explicit load condition (`"load references/X.md if [condition]"`). Flag a "see references/" pointer with no condition.

---

## 6. Frontmatter completeness (Frontmatter)

| Field | Required | Notes |
|---|---|---|
| `name` | Yes | Matches directory name |
| `description` | Yes | Trigger-phrased for auto-invokable skills ("Use when..."). Clear enough to match real user prompts. |
| `model` | Routine skills only | See model calibration below |
| `disable-model-invocation` | As recorded | Must match the project's invocation-gating table (in `AGENTS.md`, then `docs/dev/skills.md`). A skill marked open there carries an explicit-request check in its body instead. Flag any skill whose flag differs, but never add or remove the flag to fix it. A new side-effect skill (creates PRs, opens issues, pushes commits, modifies shared state) is gated unless its body has an explicit-request check, and gets a row in that table. With no gating table, skip the comparison and say so in the report |
| `allowed-tools` | Recommended | List specific `Bash(pattern *)` entries to reduce permission prompts |

**Model calibration:**

| `model` | Use for |
|---|---|
| `haiku` | Routine, well-defined tasks: commit messages, issue creation, label lookup |
| *(omitted)* | Everything requiring reasoning, synthesis, or cross-file analysis: code review, doc repair, design docs. The skill runs on the session's default model. |

Flag any dated model ID (`claude-haiku-4-5-20251001`, say) as stale — pin the `haiku` alias. Flag any non-haiku `model` pin as stale — judgment skills omit the field.
Flag `haiku` on skills that require non-obvious judgment or cross-file synthesis as under-powered.
Flag a routine mechanical skill with no `model` as over-powered — it should pin haiku.

## 7. Stale references (Stale)

If the skill names labels, fetch the label set (`gh label list --limit 100`). Flag:

- a label the skill names that no longer exists in the repository
- a branch pattern that differs from [git-conventions.md](git-conventions.md) § Branch names
- a hardcoded value (project board number, owner, repository name) that has changed
- a reference to another skill (`/fix-pr-findings`, `/pre-merge`) that was renamed or removed

Leave a facts block alone: in a project copy `/setup-skills` writes it.
