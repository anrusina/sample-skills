---
name: setup-skills
description: "Copy the sample-skills into the current project and tailor them: write the project's facts into each skill, keep only the stack and field assets it uses, and later update the copy from upstream, connect or disconnect an asset, or add or remove a skill. Clones the upstream repository, writes only under .agents/ plus the .claude/skills link, then commits and opens a PR with /commit-and-pr. Trigger: /setup-skills [install|update|connect ID|disconnect ID|add SKILL|remove SKILL] [--dry-run] [--source OWNER/REPO[@REF]]."
disable-model-invocation: true
allowed-tools:
  - Bash(git clone *)
  - Bash(git -C * rev-parse *)
  - Bash(git -C * checkout *)
  - Bash(git -C * diff *)
  - Bash(git -C * show *)
  - Bash(git rev-parse *)
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git hash-object *)
  - Bash(gh repo view *)
  - Bash(mktemp *)
  - Bash(mkdir -p .claude)
  - Bash(ln -s ../.agents/skills .claude/skills)
  - Bash(ln -s ../../.agents/skills/*)
  - Bash(ls *)
  - Bash(${CLAUDE_SKILL_DIR}/scripts/setup.sh *)
---

You bring the generic sample-skills (the plugin's `/sample-skills:<skill>`,
which work out every project fact at run time) into a project as its own
copy, and keep that copy current. A project copy has its facts written in and
only the assets it uses, runs as `/<skill>`, and is the project's to tailor.

How a skill is built (facts block, slots, assets, scripts) is in
`docs/skill-anatomy.md`; read it from the clone in step 1 before writing
anything. The mechanical half (rendering, the lock, an update's three-way
merge) is `${CLAUDE_SKILL_DIR}/scripts/setup.sh`; run it with no argument for
its usage. This file is the judgement half: which facts, which assets, which
kind of copy, and every conflict.

Nothing is written outside `.agents/skills/`, `.agents/skills-profile.md`,
`.agents/skills-lock.json` and the `.claude/skills` link. A run that wrote
files ends, once nothing is left to decide, with `/commit-and-pr` (or
`/commit` when the branch already has an open PR): the project's copy when it
has one, otherwise `/sample-skills:commit-and-pr`. The developer reviews the
change in the PR. A `--dry-run` writes and commits nothing.

## input

`$ARGUMENTS`:

| Argument | Does |
|---|---|
| empty or `install` | first copy into this project |
| `update` | bring the copy up to the latest upstream; also writes every profile edit into the skills |
| `connect <id>` / `disconnect <id>` | add or remove one stack or field asset across all installed skills |
| `add <skill>` / `remove <skill>` | add or remove one skill |
| `--dry-run` (with `install` or `update`) | do everything up to writing, show what would change, write nothing |
| `--source <owner/repo>[@<ref>]` | at install, take upstream from a fork or a ref instead of `anrusina/sample-skills` at its default branch; it is recorded, so later runs use it too |

Anything else: print this table and stop.

## the two kinds of copy

Asked at install (step 3). Both write the facts into each skill.

- **Managed.** The facts live in `.agents/skills-profile.md`, and
  `.agents/skills-lock.json` records the upstream source, ref and commit and
  the hash of each file as `setup.sh` rendered it from that commit (never as
  on disk, so a project edit stays an edit). `update` merges upstream changes
  with the project's edits, and a profile edit reaches every skill. For
  projects that want upstream improvements.
- **Detached.** No profile and no lock: the copy is the project's to edit
  freely. `update` can only compare it with upstream and propose changes
  skill by skill. For projects that will reshape the skills.

## step 0 — preconditions

- The current folder is a git checkout (`git rev-parse --show-toplevel`);
  work at its top level.
- Read the project's `AGENTS.md` (or `CLAUDE.md` when there is none).
- Note what is there: `ls .agents/skills .claude/skills`, whether
  `.claude/skills` is a symlink or a real folder, and whether the profile and
  lock exist.
  - `install` with a lock present: it is already managed; say so and offer
    `update` instead.
  - Any other command with no lock: a detached copy (or none).

## step 1 — fetch upstream

Clone the source into a fresh temporary folder, never using the plugin's own
files, so the commit is exact and older versions can be read.

```bash
mktemp -d
```
```bash
git clone --quiet https://github.com/<source>.git <tmp>
git -C <tmp> checkout --quiet <ref>     # only when a ref is set
git -C <tmp> rev-parse HEAD
```

`<source>` and `<ref>` come from `--source` at install, from the profile's
`source:` and `ref:` on later runs of a managed copy, and otherwise default to
`anrusina/sample-skills` and its default branch. Note the commit as `<new>`. For `connect`, `disconnect`, `add` and
`remove` on a managed copy, also check out the lock's commit
(`git -C <tmp> checkout --quiet <old>`), so a new file matches the version
the copy holds. The upstream skills are `<tmp>/.agents/skills/<name>/`, every
folder there with a `SKILL.md` except `setup-skills` (`_shared` is not one).

## step 2 — work out the facts (install)

Work out each fact (the shared rows in the clone's `.agents/skills/_shared/facts.md`,
and the anatomy's optional rows) and note where each value came from
(`gh`, an AGENTS.md section by name, a manifest, the Makefile, an existing
skill, or "not found"). A value found here is never looked up again, so look
wider than the skills' own rules:

- `<repo>`, `<base>`: `gh repo view`.
- wrapper: AGENTS.md as a whole (a "run tools through …" rule anywhere), and
  the tool-version file: a `mise.toml` or `.mise.toml` means `mise exec --`
  unless AGENTS.md says otherwise. **Wrapped tools**: the tools that config
  file lists (`gh`, `node`, `flutter` …); they go in the profile's
  `wrapped-tools`.
- gates: AGENTS.md's build section. When it lists both separate commands and
  one command that runs them all (a `make check`), the gates fact is the one
  command; read the Makefile or task runner to confirm what it runs.
- format fix: the write-mode formatter when the format gate only checks
  (`--check`, `--set-exit-if-changed`, `--diff`); when the format gate itself
  writes, `none (the format gate writes)`.
- setup: AGENTS.md *Worktree setup*, or any section that says what a fresh
  checkout needs (code generation, dependency install, trusting a
  tool-version file).
- build-input docs: AGENTS.md *Project structure*, and any content folder the
  build reads Markdown from.
- every optional fact in the anatomy's list, stored as the **whole** text of
  the section it names, not a pointer to it.
- **the project's existing skills.** Read every skill in `.agents/skills/` or
  `.claude/skills/` that upstream would replace. They often hold facts
  AGENTS.md lacks (a wrapper-prefixed `gh`, a version-bump target, fixture
  links, setup steps, a board number); take each into the proposal with
  `From: existing skill <name>`.
- assets: each stack id whose marker file is at the repo root, and each field
  id whose condition holds, read as the anatomy's id table words it
  (`web-site` needs rules for search, links, claims or a budget; `fonts`
  needs a font build, not bundled fonts).
- skills: all upstream skills by default.

Three facts are required: `<repo>`, `<base>` and the gates. Ask for a missing
one in the step 3 proposal; never guess a gate command. Every other fact may
be `none`. A setup step not found in the project is only proposed (from the
loaded stack assets' *Setup* sections, in start-task), for the developer to
confirm.

## step 3 — propose, and ask once

Show one proposal and ask for one answer:

1. **Facts**: a table `Fact | Value | From`, the missing ones marked. For each
   value the developer supplies rather than the repo, give the line to add to
   AGENTS.md and its section; this skill doesn't write AGENTS.md itself.
2. **Assets**: connected ids, and each id not connected with its condition, so
   the developer can add or drop one.
3. **Skills**: the list to install. Name anything worth dropping: the
   coordinator roles (`coding-master`, `managerial`) need the Claude desktop
   app; `feedback-review` assumes a feedback inbox.
4. **Kind of copy**: managed (recommended when the project wants upstream
   updates) or detached.
5. **Conflicts**: each upstream skill whose name the project already uses
   (count it once when `.claude/skills` links to `.agents/skills`):
   - in `.agents/skills/`: keep the project's skill (the default; recorded
     under `kept`, so `update` leaves it alone) or replace it. For a
     replacement, summarise what the project's version has that upstream's
     lacks, and which of it step 2 carried into the facts;
   - in a real `.claude/skills/` folder: only keep, since Claude Code would go
     on loading that copy; to replace it, the developer moves or removes that
     folder first, then runs `add <skill>`.

With `--dry-run`, show the proposal and the files step 4 would write with
the defaults (managed copy, every proposed skill and asset, conflicts kept),
remove the clone, and stop.

## step 4 — write the copy

1. **Write the profile** in the format below. A detached copy uses one too,
   as a temporary file (`mktemp`) with `kind: detached`, removed at the end.
2. **Render each chosen skill** (it deletes the skill's folder first):
   ```bash
   ${CLAUDE_SKILL_DIR}/scripts/setup.sh render <profile> <tmp>/.agents/skills <skill>
   ```
   It keeps only the connected assets, renders the facts block (the
   anatomy's *Project form*), removes the "Generic copy" sentence, and adds
   the project's commands and wrapped tools to `allowed-tools`. The first
   render also writes `.agents/skills/_shared/`, the files the skills share
   (not a skill); `update` keeps it current and the lock records it.
3. **Claude Code discovery.** If `.claude/skills` doesn't exist:
   `mkdir -p .claude` then `ln -s ../.agents/skills .claude/skills`. If it
   already links there, leave it. If it is a real folder, link each rendered
   skill, and `_shared`, into it (`ln -s ../../.agents/skills/<skill> .claude/skills/<skill>`)
   unless the name is taken there, and name the taken ones.
4. **Managed only:** write the lock:
   ```bash
   ${CLAUDE_SKILL_DIR}/scripts/setup.sh lock .agents/skills-profile.md <tmp>/.agents/skills <new>
   ```

### the profile

`.agents/skills-profile.md` is Markdown with the values in YAML frontmatter,
in the subset `setup.sh` reads (a one-line value, `[a, b]`, an indented block
of `- item` lines, or a `|` block; quotes are fine):

```markdown
---
kind: managed
source: anrusina/sample-skills
ref: main
skills: [arrow-check, commit, commit-and-pr, pr, review-pr]
kept: [start-task]
assets: [python, generated-artifacts]
wrapped-tools: [gh, python]
facts:
  repo: acme/widgets
  base: main
  wrapper: mise exec --
  gates: [make check]
  format-fix: none (the format gate writes)
  setup:
    - python3 -m venv .venv
    - .venv/bin/pip install -r requirements.txt
  build-input-docs: none
  source-and-test-dirs: [src/, tests/]
  dependency-policy: |
    Before adding a package, check on its registry that the version was
    published at least 14 days ago, and record the check beside it.
  pre-merge-checks: none
  milestones: none
---

The project facts every skill in `.agents/skills/` was written with.
Edit a value here, then run `/setup-skills update` to write it into the
skills. Run `/setup-skills connect <id>` or `disconnect <id>` to change the
assets.
```

Fact keys are the row names in lower case with dashes (`format fix` →
`format-fix`, `<repo>` → `repo`); a fact left out renders as `none`.

## step 5 — commit and report

Commit `.agents/` and `.claude/skills` together and open the PR, as the
opening section says. Then report:

- the kind of copy, the upstream source and commit (short), and the files
  written, grouped by skill;
- the facts that came from the developer, with the AGENTS.md lines to add;
- the PR;
- that the plugin's skills stay reachable as `/sample-skills:<skill>`, and the
  project's copies now answer to `/<skill>`.

Remove the temporary clone.

## update

**Managed copy.** Read the profile and the lock; fetch upstream (step 1);
`<old>` is the lock's commit. Preview, then apply:

```bash
${CLAUDE_SKILL_DIR}/scripts/setup.sh plan .agents/skills-profile.md <tmp> <old> <new>
${CLAUDE_SKILL_DIR}/scripts/setup.sh update .agents/skills-profile.md <tmp> <old> <new>
```

It touches only the files the lock records and new upstream files of the
profile's skills and connected ids, never a `kept` skill or a file the project
added. Per file:

| Plan line | Meaning | Done by the script |
|---|---|---|
| `write` | never edited here | rendered afresh from `<new>` |
| `rerender` | edited here, unchanged upstream | facts block, description and `allowed-tools` rewritten from the profile; the edits stay |
| `keep` | edited here, unchanged upstream (not a SKILL.md) | left as is |
| `merge` | edited here and upstream | three-way merge of the old and new upstream, both rendered with the current profile, then rerendered; a clean merge is written |
| `new` / `delete` | added / removed upstream, never edited here | written / deleted |
| `gone` | the project deleted it | left deleted |
| `ask-delete` | removed upstream, edited here | left; ask: keep or delete |
| `ask-new` | new upstream at a path the project already uses | left; ask which to keep |

A conflict is left untouched; the script prints the rendered base and
upstream versions and its conflict-marked attempt. Show the developer each
conflict and each `ask-*` file, write what they choose, `rerender` each skill
whose SKILL.md they resolved (a conflict keeps the old facts block), then run
the `lock` command the script printed last (it writes the lock itself only
when nothing is left to decide).

A new upstream skill is offered (`add <skill>`), not added; a new upstream
asset id is listed, not connected. With no upstream change, `update` still
rewrites the facts blocks from the profile. If `.claude/skills` is a real
folder without `_shared`, link it as install step 4.3 does.

**Detached copy.** Read the facts back from the facts blocks into a temporary
profile, print each upstream file with `setup.sh render-file` into a
`mktemp -d` folder (never `render`, which replaces `.agents/skills/<skill>/`),
and show `git diff --no-index <project skill> <rendered skill>` skill by
skill, summarising what upstream changed. Apply only what the developer
picks, by editing the project's file; never overwrite it whole.

## connect, disconnect

Check the id is in the anatomy's id table. Managed: add it to (or remove it
from) the profile's `assets`, then, with the clone at the lock's commit:

```bash
${CLAUDE_SKILL_DIR}/scripts/setup.sh assets .agents/skills-profile.md <tmp>/.agents/skills
${CLAUDE_SKILL_DIR}/scripts/setup.sh lock .agents/skills-profile.md <tmp>/.agents/skills <old>
```

It syncs the asset files, each `assets/index.md` and each facts block's
assets line; an edited asset file is listed, not removed: ask about it.
Detached: copy or
remove the asset files by hand (ask before removing any) and edit the assets
line.

## add, remove

`add <skill>` (managed): when the project already has that skill (a kept
one), first summarise what its copy has that upstream's lacks and ask before
replacing it. Add it to the profile's `skills` (and take it out of `kept`),
`render` it with the clone at the lock's commit (and link it as in install
step 4.3), then rerender every other installed skill, so their skill-names
rows name it as `/<skill>`, and write the lock:

```bash
${CLAUDE_SKILL_DIR}/scripts/setup.sh render .agents/skills-profile.md <tmp>/.agents/skills <skill>
${CLAUDE_SKILL_DIR}/scripts/setup.sh rerender .agents/skills-profile.md <tmp>/.agents/skills
${CLAUDE_SKILL_DIR}/scripts/setup.sh lock .agents/skills-profile.md <tmp>/.agents/skills <old>
```

`remove <skill>`: show the edits the project made to it (files whose hash
differs from the lock), then delete `.agents/skills/<skill>/` (and its link
in a real `.claude/skills/` folder), take it out of the profile, rerender the
others (their rows now name it `/sample-skills:<skill>`) and write the lock. Name each installed skill that
calls the removed one. Detached: render or delete the skill the same way,
then edit the skill-names row in every other skill by hand.

The Arrow of Intent is part of every skill; there is no switch for it.
`setup-skills` itself is never copied into a project.
