# Agent Skills — Arrow of Intent template

A ready-to-use set of AI workflow skills following the [Agent Skills](https://agentskills.io) open standard and the **Arrow of Intent** methodology (HLD → LLD → EARS specs → tests → code).

Companion repository to: _[your article link here]_

The same skills are used in three ways:

- **As a Claude Code plugin.** Installed once per laptop, every skill is available in every project as `/sample-skills:<skill>`, so a new project can use them from its first session. These generic copies work out each project fact at run time.
- **As a project's own copy.** Once a project wants skills tuned to it, `/sample-skills:setup-skills` copies them into the project's `.agents/skills/`, writes the project's facts into each one and keeps only the stack and field assets the project uses. The project commits that copy, tailors it, and runs it as `/<skill>`.
- **As a Codex skill set.** `scripts/install-codex.sh` copies the skills into `~/.agents/skills/` as `sample-skills-<skill>`, all but `setup-skills` (the plugin's installer) and the two coordinator roles (they need the Claude desktop app).

A typical path: install the plugin, start a new repository with the generic skills, then in one of the first commits run `/sample-skills:setup-skills`, review what it wrote, and commit the project's own copy.

## What's included

16 skills covering the development lifecycle:

| Skill | Purpose |
|---|---|
| `start-task` | Pre-coding gate: fetch the issue, check the HLD → LLD → EARS chain, set up a worktree and branch |
| `commit` | Stage the task's changes, run the quality gates, write the commit message, commit and push |
| `commit-and-pr` | `/commit`, then `/pr` |
| `pr` | Open a pull request: title, labels, `Closes #N`, spec coverage, testing checklist |
| `review-pr` | Code review in an isolated worktree, with severity-ranked findings and AI-ready fix prompts |
| `fix-pr-findings` | Triage review findings, then fix the chosen ones with sub-agents, one after another |
| `pre-merge` | Classify review threads, rebase, check EARS IDs are unique, run pre-merge checks, rebuild history as docs then implementation, file follow-ups, merge on an explicit OK |
| `issue` | Create a GitHub issue that traces up the Arrow of Intent chain |
| `design-docs` | Write and validate HLD, LLD and EARS specs |
| `arrow-check` | Validate consistency across HLD, LLDs and EARS specs |
| `doc-audit` | Quick documentation audit of the current branch — report only |
| `doc-audit-full` | Full documentation pass: doc comments, guides, Mermaid diagrams, skill files |
| `feedback-review` | Triage feedback issues: deduplicate, summarise, batch actions on confirmation |
| `coding-master` | Coordinator role for the Claude desktop app: one task session per issue, a context-free reviewer per PR, the owner holds every merge |
| `managerial` | Phase-manager role: plan a delivery phase, keep its tickets, tracks and progress doc true to GitHub, hand off |
| `setup-skills` | Bring the skills into a project as its own copy, and keep that copy current (plugin only; never copied into a project) |

### The session pipeline

```
/start-task <N>  → docs and code → /commit-and-pr          (task session)
/review-pr <P> --post                                       (reviewer session, no task context)
/fix-pr-findings <P> → owner picks → fixes as new commits   (task session)
… repeat review and fix until no findings …
/pre-merge <P>   on the owner's explicit OK                 (task session)
```

`/coding-master` runs this pipeline for several issues at once from one coordinator session; `/managerial` decides which issues run and in what order. From the plugin, each name above is `/sample-skills:<name>`; the coordinator works out which form a project uses and sends that.

### Invocation gating

Four skills are gated with `disable-model-invocation: true`, so only a person typing the command starts them: `coding-master`, `managerial`, `feedback-review` and `setup-skills`. Each starts sessions, edits tickets, closes issues or writes many files, and no pipeline relays it. The rest load on their own when the task matches; the ones that push, post or merge guard themselves in their own steps (`pre-merge` runs only on an explicit OK, `review-pr` asks before posting, `fix-pr-findings` stops after triage).

## How the skills find a project's facts

Each skill has one **facts block**, a `## Project facts` section between `<!-- facts:begin -->` and `<!-- facts:end -->` markers. Nothing else in the skill differs between the plugin and a project copy.

- **In the plugin**, the block says how to find each fact at the start of a run, and the skill writes the values into its commands:

  | Fact | Source |
  |---|---|
  | Repository, default branch | `gh repo view` |
  | Tool wrapper, quality gates, write-mode formatter | `AGENTS.md`, the section that lists the build and test commands |
  | Worktree setup | `AGENTS.md` → *Worktree setup* |
  | Markdown that feeds the build | `AGENTS.md` → *Project structure* |
  | Extra pre-merge checks, releases, project board, milestones, feedback inbox | the matching `AGENTS.md` section (optional) |
  | Stack and field assets | manifest files at the repo root, and what `AGENTS.md` declares |

  Sections are matched by what they hold, not their exact title. When a required fact is missing, the skill asks once and tells you which `AGENTS.md` section to record it in.
- **In a project copy**, `/setup-skills` has replaced the block with the values, so nothing is looked up.

## Stack and field assets

Anything specific to a toolchain or a kind of product lives in small files inside the skill that needs it, rather than in the skill's own text:

```
review-pr/
  SKILL.md
  assets/
    index.md                ← which assets exist here and when each applies
    stack/flutter.md        ← review checks for a Flutter app
    stack/python.md
    field/accessibility.md  ← accessibility review checks and severity floors
    …
```

The plugin loads the assets whose conditions hold for the project in front of it. A project copy holds only the assets it connected, and uses all of them.

| Kind | Ids |
|---|---|
| stack | `flutter`, `node`, `python`, `rust`, `go`, `jvm`, `ruby` |
| field | `accessibility`, `i18n`, `frontend-ui`, `web-site`, `generated-artifacts`, `fonts` |

A skill only has the assets it has something to say for: `commit` has a dependency-registry lookup per stack, `review-pr` has review checks per stack and field. The full contract (facts block, slots, ids) is in [docs/skill-anatomy.md](docs/skill-anatomy.md).

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

Every skill is then available in every project as `/sample-skills:<skill>`, for example `/sample-skills:commit`. Plugin skills are namespaced, so they never shadow a project's own skills: in a project with its own `commit` skill, `/commit` runs the project's version and the generic one stays reachable as `/sample-skills:commit`. Each generic description also says a project's own skill takes precedence, so Claude picks the project's version when it chooses a skill by itself.

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

It leaves out `setup-skills`, `coding-master` and `managerial`, and writes each skill's installed path where Claude Code would fill in `${CLAUDE_SKILL_DIR}`. To update, `git pull` in the clone and run the script again; it builds each skill in a temporary folder, replaces only the folders it installed (each carries a `.installed-by-sample-skills` marker) and drops skills that were removed upstream. `scripts/install-codex.sh --uninstall` removes them.

## Give a project its own copy

In the project, run:

```
/sample-skills:setup-skills
```

It works out the project's facts and assets, shows them in one proposal for you to correct, and asks which kind of copy you want:

- **Managed**: the facts live in `.agents/skills-profile.md`, and `.agents/skills-lock.json` records the upstream commit. `/sample-skills:setup-skills update` later brings in upstream changes and merges them with the project's own edits; editing the profile and running `update` changes a fact in every skill.
- **Detached**: the facts are written into each skill and the copy is the project's from then on, to reshape freely. `update` can still compare it with upstream and propose changes skill by skill.

Either way it writes `.agents/skills/`, links `.claude/skills` to it for Claude Code, and commits nothing: review the diff, then commit it. Later:

```
/sample-skills:setup-skills connect accessibility     # add an asset to every skill that has one
/sample-skills:setup-skills disconnect i18n
/sample-skills:setup-skills add feedback-review
/sample-skills:setup-skills update --dry-run          # see what upstream changed, write nothing
```

Copy [`AGENTS.md`](AGENTS.md) too if the project has none (or merge its sections into the project's own): the skills and `/setup-skills` both read it.

**Without the plugin**, copy by hand: `cp -R path/to/sample-skills/.agents path/to/project/`, `ln -s ../.agents/skills path/to/project/.claude/skills`, delete `setup-skills` and the assets the project doesn't use, and fill in `AGENTS.md`. The skills then work out their facts at run time, as the plugin's do.

The generic skills run `git` and `gh` bare and wrap only the gates and the tools the project's wrapper provides, so their `allowed-tools` match. A project copy adds its own commands (the gates, setup steps, any wrapper-provided tool) to each skill's `allowed-tools`; `/setup-skills` does this when it writes the copy.

## Structure

```
.agents/
  skills/
    <name>/
      SKILL.md           ← skill instructions (Agent Skills standard), with its facts block
      assets/            ← output templates, plus stack/ and field/ assets and their index.md
      references/        ← reference docs loaded on demand
      scripts/           ← fixed git/gh sequences the skill runs (see docs/skill-anatomy.md § Scripts)
.claude/
  skills -> ../.agents/skills   ← symlink for Claude Code project discovery
.claude-plugin/
  plugin.json            ← the plugin (skills from ./.agents/skills)
  marketplace.json       ← the marketplace listing that one plugin
docs/
  skill-anatomy.md       ← how a skill is built: facts block, slots, assets, ids
scripts/
  install-codex.sh       ← laptop-wide install for Codex
  check-shared-scripts.sh ← fails when two copies of a shared skill script differ
AGENTS.md                ← standing-instructions template the skills read
```

## License

MIT.
