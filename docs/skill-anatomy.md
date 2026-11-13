# Skill anatomy

How every skill in this repository is built, so it runs in two places from the
same files:

- **From the plugin** (the generic copy): installed once per laptop, used in
  any project as `/sample-skills:<skill>`. It knows nothing about the project,
  so it works out each project fact at run time.
- **From a project copy**: `/setup-skills` copies the skills into a project's
  `.agents/skills/`, writes the project's facts into each one, and copies in
  only the stack and field assets the project uses. The copy runs as
  `/<skill>` and looks nothing up.

The Arrow of Intent (HLD → LLDs → EARS specs → tests → code) is part of every
skill's core. It is not an asset and cannot be switched off.

## The facts block

Every skill that needs a project fact has one `## Project facts` section, right
after its opening paragraphs, wrapped in markers:

```markdown
## Project facts

<!-- facts:begin -->
…
<!-- facts:end -->
```

Everything between the markers is owned by `/setup-skills`. In the generic copy
it says how to find each fact. In a project copy, `/setup-skills` replaces it
with the literal values. Outside the block, the only differences are the
description's closing sentence (removed), `allowed-tools` (adapted to the
project's wrapper and commands) and the assets left out.

### Generic form

The generic block lists **only the facts that skill uses**, each with its rule,
followed by the closing paragraphs that apply. Use exactly these rule texts so
`/setup-skills` and a reader see the same thing in every skill:

```markdown
## Project facts

<!-- facts:begin -->
This is the generic copy: no project facts are written into it. Work out each
fact below once, at the start of the run, then write its value literally into
every command that needs it. Each Bash call starts a fresh shell, so a variable
set in one call is empty in the next; never carry a value across calls in a
shell variable.

| Fact | How to find it |
|---|---|
| `<repo>` | `gh repo view --json nameWithOwner -q .nameWithOwner` |
| `<base>` | `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`; if that fails, `git symbolic-ref --short refs/remotes/origin/HEAD \| sed 's\|^origin/\|\|'` |
| wrapper | AGENTS.md build section: the prefix the toolchain runs through (a version manager's exec command, for example), or none. Run the gates, and each tool the wrapper provides (the tools its config file lists), through it; pass it to this skill's scripts as `--wrap '<wrapper>'`; run every other command bare, so it matches `allowed-tools` |
| gates | AGENTS.md build section: the format, lint/analyze and test commands, in order, or the one command that runs them all |
| format fix | AGENTS.md build section: the write-mode formatter, if the format gate only checks |
| setup | AGENTS.md *Worktree setup*: the steps a fresh worktree needs (dependencies, code generation), or none |
| build-input docs | AGENTS.md *Project structure*: Markdown the build reads, or none. Whatever AGENTS.md says, Markdown or MDX inside the source tree that the build reads (content collections, MDX pages, a docs site's sources) counts too. A change to any of it runs the gates like code |
| skill names | `/<name>` when the primary checkout (`dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`) holds the skill in `.agents/skills/<name>/` or `.claude/skills/<name>/`; otherwise the form this skill was installed in: `/sample-skills:<name>` from the plugin, `sample-skills-<name>` from a Codex install. Other skills are named in this file in their short form (`/<name>`); write each in the form this rule gives |
| assets | the stack and field assets that apply: see *Assets* below |

**AGENTS.md sections by role.** Projects name sections differently. The build
section is the one that lists the build, format, lint and test commands,
whatever it is called (*Build and test commands*, *Build commands*, *Tools*,
*Commands*). Match every section this skill reads the same way: by what it
holds, not by its exact title. When a required fact is missing, ask the
developer once, use the answer, and tell them which AGENTS.md section to
record it in.

**Assets.** This skill keeps stack and field assets under `assets/stack/` and
`assets/field/`; `assets/index.md` says when each applies. At the start of the
run, load every asset whose condition holds, and apply each where a step names
its section. With none loaded, the steps' generic text applies.
<!-- facts:end -->
```

Keep only the table rows the skill uses, and drop the *Assets* paragraph from
a skill without assets. A skill with optional facts adds rows for them in the
same style, "AGENTS.md *Project board*: …, or none (skip the steps that
need it)", saying in the rule which part of the section *this* skill needs.
The optional rows in use, by name (one name means one fact, and one key in a
project's profile):

| Fact | Section | Used by |
|---|---|---|
| source and test dirs | *Project structure* | pr |
| dependency policy | *Security → Dependency policy*, or the file it points to | commit, managerial |
| pre-merge checks | *Pre-merge checks* (incl. a version bump and the files it writes) | pr, pre-merge |
| fixtures | testing section: git-ignored fixture folders and how to link them | review-pr |
| releases | *Releases* | pre-merge, coding-master |
| manual workflows | build or release section: workflows run by hand | coding-master |
| project board | *Project board* | issue, pre-merge, managerial |
| milestones | *Milestones*: active vs backlog, and how one is chosen | issue, pre-merge, start-task |
| backlog milestone | *Milestones*: the backlog one | managerial, feedback-review |
| feedback labels, inbox milestone | *Feedback* | feedback-review |
| blast-radius map | a section mapping the project's parts to the blast-radius levels | review-pr |

**Run-time rows.** A row whose value must be current on every run, such as
`labels` (`gh label list`, read at run time), keeps its rule in a project copy
too: `/setup-skills` copies it unchanged instead of writing a value.

The `wrapper`, `build-input docs` and `skill names` rows are word for word
the same in every skill that has them, so a reader learns each once and a
fix lands everywhere. `wrapper` is applied as its row says, not per command:
the body names no wrapper. Wrapping only what the wrapper provides keeps
plain `git` and `gh` calls matching the skill's `allowed-tools`; a project
whose version manager provides `gh` lists it in that manager's config, and
the rule wraps it there.

The `skill names` row, and the closing sentence about short forms, replace
every per-skill variant: skills never restate it in their own words.

### Project form

`/setup-skills` writes the same table with values instead of rules, and the
assets line names what was copied in:

```markdown
## Project facts

<!-- facts:begin -->
Written by /setup-skills from `.agents/skills-profile.md` (managed copy: edit
the profile and run `/setup-skills update`, not this block).

| Fact | Value |
|---|---|
| `<repo>` | `acme/widgets` |
| `<base>` | `main` |
| wrapper | `mise exec --` |
| gates | `make check` |
| …

Assets: every file under `assets/stack/` and `assets/field/` applies (python,
generated-artifacts).
<!-- facts:end -->
```

A **detached** copy has the same block with a first line that says it is the
project's own copy, edited by hand.

## Commands in the body

- `<repo>` and `<base>` in a command are slots: write the fact's value in.
- `gh api repos/{owner}/{repo}/…` is fine as is: `gh` fills `{owner}` and
  `{repo}` itself from the current checkout.
- Other per-run values (a PR number, an issue number, a SHA) are also slots,
  written in literally. A step that needs a value computed in an earlier call
  says so: "the SHA noted in step 3".
- Never `VAR=$(…)` in one fenced block and `$VAR` in another. A single block
  that sets and uses a variable in one call is fine.
- Body text files go through `mktemp`, never a fixed `/tmp/<name>` that two
  sessions can share.

## Assets

Stack- and field-specific text lives in the skill that needs it, as small
files under `assets/`:

```
<skill>/
  SKILL.md
  assets/
    index.md            ← which assets exist and when each applies
    stack/<id>.md       ← one per toolchain
    field/<id>.md       ← one per kind of product concern
    <templates>.md      ← output templates, as before
  references/           ← reference docs, as before
```

A skill only has the assets it has something to say for: `review-pr` has
review checks per stack and field, `commit` has registry lookups per stack.
Each asset file has H2 sections named after the steps that load them (for
example `## Review checks`, `## Dependency registry`). The SKILL.md step says
"apply the *Review checks* section of each loaded asset"; an asset without
that section adds nothing there.

Assets point at the project's own rule lists and never copy them: "apply every
rule in AGENTS.md's accessibility section", not a restated list.

### Ids

The same ids are used in every skill, so `/setup-skills` can connect one id
across all skills at once.

| Kind | Id | Applies when (generic copy) |
|---|---|---|
| stack | `flutter` | `pubspec.yaml` at the repo root |
| stack | `node` | `package.json` at the repo root (covers TypeScript, React, Astro and other Node toolchains) |
| stack | `python` | `pyproject.toml`, `requirements*.txt` or `setup.py` at the repo root |
| stack | `rust` | `Cargo.toml` at the repo root |
| stack | `go` | `go.mod` at the repo root |
| stack | `jvm` | `pom.xml` or `build.gradle*` at the repo root |
| stack | `ruby` | `Gemfile` or a `*.gemspec` at the repo root |
| field | `accessibility` | AGENTS.md has accessibility rules (a section, or WCAG named) |
| field | `i18n` | the project ships more than one locale, or AGENTS.md has localisation rules (translation files, no hard-coded strings) |
| field | `frontend-ui` | the project has a user interface with a theme or design tokens, or AGENTS.md has layout or theming rules |
| field | `web-site` | the project is a public web site with rules for search, links, product claims or a performance budget (AGENTS.md has such rules; a web *app* without them doesn't qualify) |
| field | `generated-artifacts` | build outputs are committed alongside their sources (whatever AGENTS.md calls them: generated files, built assets, outputs a `make` target writes into the tree) |
| field | `fonts` | the project **builds** fonts from sources (glyph drawings, manifests, code points); bundling or using fonts doesn't qualify |

`assets/index.md` in each skill repeats the rows for the ids that skill has, with
one line on what each provides there.

## Description suffix

Every generic description ends with *"Generic template: a project's own
`<name>` skill takes precedence."* With the plugin installed, a project's own
skill of the same name loads beside it, and the sentence steers Claude to the
project's version. `/setup-skills` removes the sentence from project copies.

`setup-skills` is the exception to this page: it is the installer, never
copied into a project, so it has no facts block, no assets and no suffix.

## Model pins

Pin a model only where a smaller one is enough for the skill's work:
`commit`, `commit-and-pr`, `issue` and `pr` pin `haiku`. Always pin the
alias, never a dated model ID, so each run gets the latest version of that
model. Skills whose work needs the strongest reasoning (review, design,
coordination) set no `model` and run on the session's.
