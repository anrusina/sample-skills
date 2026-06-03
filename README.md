# Agent Skills — Arrow of Intent template

A ready-to-use set of AI workflow skills following the [Agent Skills](https://agentskills.io) open standard and the **Arrow of Intent** methodology.

Companion repository to: _[your article link here]_

## What's included

12 skills covering the full development lifecycle:

| Skill | Purpose |
|---|---|
| `commit` | Inspect changes, run quality gates, produce a commit message |
| `commit-and-pr` | Stage, commit, branch, and open a PR in one step |
| `pr` | Create a pull request from the current branch |
| `review-pr` | Code review with severity-ranked findings |
| `fix-pr-findings` | Orchestrate fixes for review findings via parallel sub-agents |
| `pre-merge` | Classify threads, reply to addressed ones, generate squash message |
| `issue` | Create a GitHub issue following the Arrow of Intent chain |
| `design-docs` | Write and validate HLD, LLD, and EARS specs |
| `arrow-check` | Validate consistency across HLD, LLDs, and EARS specs |
| `doc-audit` | Quick documentation audit — report only |
| `doc-audit-full` | Full doc pass: fix comments, repair diagrams, optimise skills |
| `feedback-review` | Review and incorporate feedback from external sources |

## How to use

1. Copy `.agents/skills/` into your repository root.
2. Copy `AGENTS.md` into your repository root and fill in the project-specific sections.
3. If you use Claude Code, the `.claude/skills` symlink is already wired up.
4. Replace all placeholders (see below) with your project's values.
5. Replace the `flutter/` convention files with your language or framework equivalent.

## Placeholders

The following placeholders appear in skill files and must be replaced with your project's values before use:

| Placeholder | Where it appears | Replace with |
|---|---|---|
| `{owner}` | `issue`, `pre-merge`, `commit-and-pr` | Your GitHub username or org (e.g. `myorg`) |
| `{repo}` | `fix-pr-findings` example URLs | Your repository name (e.g. `my-app`) |
| `{project_id}` | `issue`, `pre-merge`, `commit-and-pr` | Your GitHub project board number (find it in the project URL) |

You can find all occurrences with:
```bash
grep -rn "{owner}\|{repo}\|{project_id}" .agents/skills/
```

If you don't use a GitHub project board, remove the `gh project item-add` lines from `issue`, `pre-merge`, and `commit-and-pr`.

## Language and framework conventions

Flutter-specific quality gates and conventions live in `flutter/` subfolders within each skill:

```
commit/
├── SKILL.md                    ← universal procedure
└── flutter/
    ├── quality-gates.md        ← dart format, flutter analyze, flutter test
    └── dependency-check.md     ← pub.dev publish-date policy

pr/ and commit-and-pr/
└── flutter/
    └── testing-checklist.md   ← PR testing section

doc-audit/ and doc-audit-full/
└── flutter/
    └── dart-conventions.md    ← Dart doc comment style, Mermaid conventions
```

To adapt for another language or framework, replace the `flutter/` files with your own and update the `<!-- TODO -->` references in each `SKILL.md`.

## Structure

```
.agents/
  skills/
    <name>/
      SKILL.md           ← skill instructions (Agent Skills standard)
      flutter/           ← language-specific conventions
      assets/            ← output templates loaded on demand
      references/        ← reference docs loaded on demand
.claude/
  skills -> ../.agents/skills   ← symlink for Claude Code discovery
AGENTS.md                        ← standing instructions for AI agents
```

## License

MIT
