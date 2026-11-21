# Project facts

How a skill's generic copy works out the facts its *Project facts* block
lists. A project copy that `/setup-skills` wrote holds the values instead and
never reads this file.

Work out each fact once, at the start of the run, then write its value
literally into every command that needs it. Each Bash call starts a fresh
shell, so a variable set in one call is empty in the next; never carry a value
across calls in a shell variable.

## Shared rows

A row marked *shared* in a skill's block takes its rule from here.

| Fact | How to find it |
|---|---|
| `<repo>` | `gh repo view --json nameWithOwner -q .nameWithOwner` |
| `<base>` | `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`; if that fails, `git symbolic-ref --short refs/remotes/origin/HEAD \| sed 's\|^origin/\|\|'` |
| wrapper | AGENTS.md build section: the prefix the toolchain runs through (a version manager's exec command, for example), or none. Run the gates, and each tool the wrapper provides (the tools its config file lists), through it; pass it to this skill's scripts as `--wrap '<wrapper>'` (leave `--wrap` out when it is none); run every other command bare, so it matches `allowed-tools` |
| gates | AGENTS.md build section: the format, lint/analyze and test commands, in order, or the one command that runs them all |
| format fix | AGENTS.md build section: the write-mode formatter, if the format gate only checks |
| setup | AGENTS.md *Worktree setup*: the steps a fresh worktree needs (dependencies, code generation), or none |
| build-input docs | AGENTS.md *Project structure*: Markdown the build reads, or none. Whatever AGENTS.md says, Markdown or MDX inside the source tree that the build reads (content collections, MDX pages, a docs site's sources) counts too. A change to any of it runs the gates like code |
| skill names | `/<name>` when the primary checkout (`dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`) holds the skill in `.agents/skills/<name>/` or `.claude/skills/<name>/`; otherwise the form the skill was installed in: `/sample-skills:<name>` from the plugin, `sample-skills-<name>` from a Codex install. Other skills are named in the skill's file in their short form (`/<name>`); write each in the form this rule gives |
| assets | the stack and field assets that apply: see *Assets* below |

## AGENTS.md sections by role

Projects name sections differently. The build section is the one that lists
the build, format, lint and test commands, whatever it is called (*Build and
test commands*, *Build commands*, *Tools*, *Commands*). Match every section
the skill reads the same way: by what it holds, not by its exact title. When
a required fact is missing, ask the developer once, use the answer, and tell
them which AGENTS.md section to record it in.

## Assets

A skill with an `assets` row keeps stack and field assets under
`assets/stack/` and `assets/field/`; its `assets/index.md` says when each
applies. At the start of the run, load every asset whose condition holds, and
apply each where a step names its section. With none loaded, the steps'
generic text applies.
