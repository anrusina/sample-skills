# Agent Skills — Arrow of Intent template

A ready-to-use set of AI workflow skills following the [Agent Skills](https://agentskills.io) open standard and the **Arrow of Intent** methodology (HLD → LLD → EARS specs → tests → code).

Companion repository to: _[your article link here]_

The repository is three things at once:

- **A template.** A project copies `.agents/skills/` and `AGENTS.md` into its own repository and tailors them.
- **A Claude Code plugin and marketplace.** Installed once per laptop, every skill is available in every project as `/sample-skills:<skill>`, so a new project can use them from its first session.
- **A Codex skill set.** `scripts/install-codex.sh` copies the skills into `~/.agents/skills/` as `sample-skills-<skill>`.

## What's included

17 skills covering the development lifecycle:

| Skill | Purpose |
|---|---|
| `start-task` | Pre-coding gate: fetch the issue, check the HLD → LLD → EARS chain, set up a worktree and branch |
| `commit` | Stage the task's changes, run the quality gates, write the commit message, commit and push |
| `commit-and-pr` | `/commit`, then `/pr` |
| `pr` | Open a pull request: title, labels, `Closes #N`, spec coverage, testing checklist |
| `review-pr` | Code review in an isolated worktree, with severity-ranked findings and AI-ready fix prompts |
| `fix-pr-findings` | Triage review findings, then fix the chosen ones via parallel sub-agents |
| `pre-merge` | Classify review threads, rebase, check EARS IDs are unique, run pre-merge checks, rebuild history as docs then implementation, file follow-ups, merge on an explicit OK |
| `issue` | Create a GitHub issue that traces up the Arrow of Intent chain |
| `design-docs` | Write and validate HLD, LLD and EARS specs |
| `arrow-check` | Validate consistency across HLD, LLDs and EARS specs |
| `doc-audit` | Quick documentation audit of the current branch — report only |
| `doc-audit-full` | Full documentation pass: doc comments, guides, Mermaid diagrams, skill files |
| `feedback-review` | Triage feedback issues: deduplicate, summarise, batch actions on confirmation |
| `close-cli` | Save what's worth remembering before a CLI session ends |
| `coding-master` | Coordinator role for the Claude desktop app: one task session per issue, a context-free reviewer per PR, the owner holds every merge |
| `managerial` | Phase-manager role: plan a delivery phase, keep its tickets, tracks and progress doc true to GitHub, hand off |
| `frontend-design` | Distinctive visual design for new UI, copied as-is from [anthropics/skills](https://github.com/anthropics/skills/tree/main/skills/frontend-design) under the Apache License 2.0 (see its `LICENSE.txt`) |

### The session pipeline

```
/start-task <N>  → docs and code → /commit-and-pr          (task session)
/review-pr <P> --post                                       (reviewer session, no task context)
/fix-pr-findings <P> → owner picks → fixes as new commits   (task session)
… repeat review and fix until no findings …
/pre-merge <P>   on the owner's explicit OK                 (task session)
```

`/coding-master` runs this pipeline for several issues at once from one coordinator session; `/managerial` decides which issues run and in what order.

### Invocation gating

Three skills are gated with `disable-model-invocation: true`, so only a person typing the command starts them: `coding-master`, `managerial` and `feedback-review`. Each starts sessions, edits tickets or closes issues, and no pipeline relays it. The rest load on their own when the task matches; the ones that push, post or merge guard themselves in their own steps (`pre-merge` runs only on an explicit OK, `review-pr` asks before posting, `fix-pr-findings` stops after triage).

## How the skills find a project's facts

The skills carry no placeholders. Anything project-specific is found at run time:

| Fact | Source |
|---|---|
| Repository, default branch, your GitHub login | `gh repo view`, `gh api user` |
| Quality gates, tool wrapper, worktree setup | `AGENTS.md` → *Build and test commands* |
| Extra pre-merge checks, version bump | `AGENTS.md` → *Pre-merge checks* (optional) |
| What a merge deploys | `AGENTS.md` → *Releases* (optional) |
| Project board | `AGENTS.md` → *Project board* (optional) |
| Active vs backlog milestones | `AGENTS.md` → *Milestones* (optional) |
| Feedback labels and inbox milestone | `AGENTS.md` → *Feedback* (optional) |
| Spec files | `docs/specs/HLD.md`, `LLD-<subsystem>.md`, `EARS-<subsystem>.md` |
| Labels, milestones, issues | GitHub, at run time |

When a required fact is missing, the skill asks once and tells you which `AGENTS.md` section to record it in. Optional sections that are absent make the skill skip the steps that need them.

Some skills also keep a **convention file**, `conventions/<topic>.md` inside the skill, for a block a project will want to rewrite for its stack: dependency registry checks, review categories, doc-comment style, the PR testing checklist. Each ships with a working, language-neutral default.

## Install for the whole laptop

### Claude Code: as a plugin

```bash
claude plugin marketplace add anrusina/sample-skills
claude plugin install sample-skills@sample-skills --scope user
```

or, in one step inside a session (Claude Code 2.1.275 or later):

```
/plugin install sample-skills --marketplace anrusina/sample-skills
```

Every skill is then available in every project as `/sample-skills:<skill>`, for example `/sample-skills:commit`. Plugin skills are namespaced, so they never shadow a project's own skills: in a project with its own `commit` skill, `/commit` runs the project's version and the generic one stays reachable as `/sample-skills:commit`. Each description also says a project's own skill takes precedence, so Claude picks the project's version when it chooses a skill by itself.

Why a plugin and not `~/.claude/skills/`: Claude Code runs a personal skill over a project skill of the same name, so a generic `commit` there would shadow every project's tailored `/commit`.

**Getting updates.** The plugin has no `version` field, so it tracks this repository's commits:

```bash
claude plugin marketplace update sample-skills
claude plugin update sample-skills@sample-skills
```

then restart Claude Code (or run `/reload-plugins` in a session). To update automatically, open `/plugin` → **Marketplaces** → `sample-skills` → **Enable auto-update**.

### Codex

Codex reads user-level skills from `~/.agents/skills/` and, when two skills share a name, shows both. The installer copies each skill there under a prefixed folder and frontmatter name (`sample-skills-commit`), so it can't clash with a project's own `commit`:

```bash
git clone https://github.com/anrusina/sample-skills.git
sample-skills/scripts/install-codex.sh
```

To update, `git pull` in the clone and run the script again; it replaces only the folders it installed (each carries a `.installed-by-sample-skills` marker) and drops skills that were removed upstream. `scripts/install-codex.sh --uninstall` removes them.

## Give a project its own copy

Once a project wants to tailor the skills, it takes its own copy. From then on its sessions use its versions; the plugin's stay reachable by their namespaced names.

1. Copy the skills and the template into the project root:
   ```bash
   cp -R path/to/sample-skills/.agents path/to/project/
   cp path/to/sample-skills/AGENTS.md path/to/project/   # skip if the project already has one; merge the sections instead
   ```
2. Wire up Claude Code discovery:
   ```bash
   mkdir -p path/to/project/.claude
   ln -s ../.agents/skills path/to/project/.claude/skills
   ```
3. Fill in `AGENTS.md`, above all *Build and test commands*. Delete optional sections the project doesn't use.
4. Tailor what the project needs: edit the `conventions/` files for its stack, drop skills it won't use, and tighten each skill's `allowed-tools` to its own commands. The closing *"Generic template: a project's own … skill takes precedence."* sentence of each description can stay or go.
5. Commit `.agents/`, `.claude/skills` and `AGENTS.md`.

A later change to the generic skills doesn't reach a project's copy on its own: compare the project's `.agents/skills/` with this repository and port what's useful by hand.

## Structure

```
.agents/
  skills/
    <name>/
      SKILL.md           ← skill instructions (Agent Skills standard)
      conventions/       ← stack-specific blocks with generic defaults
      assets/            ← output templates loaded on demand
      references/        ← reference docs loaded on demand
.claude/
  skills -> ../.agents/skills   ← symlink for Claude Code project discovery
.claude-plugin/
  plugin.json            ← the plugin (skills from ./.agents/skills)
  marketplace.json       ← the marketplace listing that one plugin
scripts/
  install-codex.sh       ← laptop-wide install for Codex
AGENTS.md                ← standing-instructions template the skills read
```

## License

MIT, except `frontend-design`, which keeps its Apache License 2.0 (`.agents/skills/frontend-design/LICENSE.txt`).
