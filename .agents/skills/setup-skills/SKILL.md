---
name: setup-skills
description: "Copy the sample-skills into the current project and tailor them: write the project's facts into each skill, keep only the stack and field assets it uses, and later update the copy from upstream, connect or disconnect an asset, or add or remove a skill. Clones the upstream repository, writes only under .agents/ plus the .claude/skills link, and never commits. Trigger: /setup-skills [install|update|connect <id>|disconnect <id>|add <skill>|remove <skill>] [--dry-run] [--source <owner/repo>[@<ref>]]."
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
  - Bash(ls *)
  - Bash(${CLAUDE_SKILL_DIR}/scripts/setup.sh *)
---

You bring the generic sample-skills into a project as the project's own copy,
and keep that copy current. The generic skills (from the plugin, run as
`/sample-skills:<skill>`) work out every project fact at run time. A project
copy has its facts written in and only the assets it uses, so it runs as
`/<skill>`, looks nothing up, and is the project's to tailor.

How a skill is built (the facts block, slots, assets, scripts) is set out in
`docs/skill-anatomy.md` of the source repository; read it from the clone in
step 1 before writing anything. The mechanical half (rendering, the lock, an
update's three-way merge) is `${CLAUDE_SKILL_DIR}/scripts/setup.sh`; run it
with no argument for its usage. This file is the judgement half: which
facts, which assets, which kind of copy, and every conflict.

Nothing here commits, and nothing is written outside `.agents/skills/`,
`.agents/skills-profile.md`, `.agents/skills-lock.json` and the
`.claude/skills` link: the developer reviews the diff and commits it (with
`/commit` or by hand).

## input

`$ARGUMENTS`:

| Argument | Does |
|---|---|
| empty or `install` | first copy into this project |
| `update` | bring the copy up to the latest upstream; also writes every profile edit into the skills |
| `connect <id>` / `disconnect <id>` | add or remove one stack or field asset across all installed skills |
| `add <skill>` / `remove <skill>` | add or remove one skill |
| `--dry-run` (with any of the above) | do everything up to writing, show what would change, write nothing |
| `--source <owner/repo>[@<ref>]` | at install, take upstream from a fork or a ref instead of `anrusina/sample-skills` at its default branch; it is recorded, so later runs use it too |

Anything else: print this table and stop.

## the two kinds of copy

Ask which one the developer wants at install (step 4). Both write the facts
into each skill; they differ in what stays the source of truth.

- **Managed.** The facts live in `.agents/skills-profile.md`, and
  `.agents/skills-lock.json` records the upstream source, ref and commit and
  the hash of every file written. `update` then brings in upstream changes,
  merging them with the project's own edits, and a profile edit reaches
  every skill. Choose this to keep receiving upstream improvements.
- **Detached.** No profile and no lock: the copy is the project's from then
  on, to edit freely. `update` can still compare it with upstream and propose
  changes skill by skill, but cannot merge on its own. Choose this when the
  project will reshape the skills.

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

Clone the source into a fresh temporary folder: always a clone, never the
plugin's own files, so the commit is exact and older versions can be read.

```bash
mktemp -d
```
```bash
git clone --quiet https://github.com/<source>.git <tmp>
git -C <tmp> checkout --quiet <ref>     # only when a ref is set
git -C <tmp> rev-parse HEAD
```

`<source>` and `<ref>` come from `--source` at install, from the profile's
`source:` and `ref:` on any later run of a managed copy (so a fork stays the
upstream), and otherwise default to `anrusina/sample-skills` and its default
branch. Note the commit as `<new>`. For `connect`, `disconnect`, `add` and
`remove` on a managed copy, also check out the lock's commit
(`git -C <tmp> checkout --quiet <old>`), so a new file matches the version
the copy holds. The upstream skills are `<tmp>/.agents/skills/<name>/`, every
folder there except `setup-skills`.

## step 2 — work out the facts (install)

Work out each fact in the anatomy's table and note where each value came from
(`gh`, an AGENTS.md section by name, a manifest, the Makefile, an existing
skill, or "not found"). A value found here is written into every skill and
never looked up again, so look wider than the skills' own rules:

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
- every optional fact in the anatomy's list (pre-merge checks, releases,
  project board, milestones, feedback, dependency policy and the rest),
  stored as the **whole** text of the section it names, not a pointer to it:
  each skill takes the part it needs at run time.
- **the project's existing skills.** Read every skill in `.agents/skills/` or
  `.claude/skills/` that upstream would replace. They often hold facts
  AGENTS.md lacks (a wrapper-prefixed `gh`, a version-bump target, fixture
  links, setup steps, a board number); take each into the proposal with
  `From: existing skill <name>`, or it is lost with the skill.
- assets: each stack id whose marker file is at the repo root, and each field
  id whose condition holds, read as the anatomy's id table words it
  (`web-site` needs rules for search, links, claims or a budget; `fonts`
  needs a font build, not bundled fonts).
- skills: all upstream skills by default.

Three facts are required: `<repo>`, `<base>` and the gates. Ask for a missing
one in the step 4 proposal; never guess a gate command, because every skill
that runs it would then fail or, worse, pass. Every other fact may be
`none`. A setup step not found in the project is only proposed (from the
loaded stack assets' *Setup* sections, in start-task), for the developer to
confirm.

## step 3 — propose, and ask once

Show one proposal and ask for one answer:

1. **Facts**: a table `Fact | Value | From`, the missing ones marked. For each
   value the developer supplies rather than the repo, give the line to add to
   AGENTS.md (and the section it belongs in), so people and other tools see
   it too; this skill doesn't write AGENTS.md itself.
2. **Assets**: connected ids, and each id not connected with its condition, so
   the developer can add or drop one.
3. **Skills**: the list to install. Name anything worth dropping: the
   coordinator roles (`coding-master`, `managerial`) need the Claude desktop
   app; `feedback-review` assumes a feedback inbox.
4. **Kind of copy**: managed (recommended when the project wants upstream
   updates) or detached.
5. **Conflicts**: each upstream skill whose name the project already uses
   (count it once when `.claude/skills` links to `.agents/skills`):
   - in `.agents/skills/`: keep the project's skill (the default; it is then
     recorded under `kept`, so `update` leaves it alone and stops offering
     upstream's) or replace it. For a replacement, summarise what the
     project's version has that upstream's lacks, and which of it step 2
     carried into the facts;
   - in a real `.claude/skills/` folder: only keep. Claude Code would go on
     loading that folder's copy, so a replacement written to `.agents/skills/`
     changes nothing; say the developer must move or remove that folder
     first, then run `add <skill>`.

With `--dry-run`, show the proposal and the files step 4 would write with
the defaults (managed copy, every proposed skill and asset, conflicts kept),
remove the clone, and stop.

## step 4 — write the copy

1. **Write the profile** in the format below. A detached copy uses one too,
   as a temporary file (`mktemp`) with `kind: detached`, removed at the end.
2. **Render each chosen skill.** It deletes the skill's folder first, so no
   file of an old version is left behind:
   ```bash
   ${CLAUDE_SKILL_DIR}/scripts/setup.sh render <profile> <tmp>/.agents/skills <skill>
   ```
   That writes the files with only the connected assets (and `assets/index.md`
   without the others' rows), renders the facts block (the anatomy's
   *Project form*), removes the description's "Generic copy" sentence, and
   adds to `allowed-tools` the gates, format fix and setup commands of the
   skills that run them, and the wrapper-prefixed form of each wrapped tool's
   pattern.
3. **Claude Code discovery.** If `.claude/skills` doesn't exist:
   `mkdir -p .claude` then `ln -s ../.agents/skills .claude/skills`. If it
   already links there, leave it. If it is a real folder, don't touch it:
   name the skills it holds that are now shadowed or duplicated.
4. **Managed only:** write the lock:
   ```bash
   ${CLAUDE_SKILL_DIR}/scripts/setup.sh lock .agents/skills-profile.md <new>
   ```

### the profile

`.agents/skills-profile.md` is Markdown with the values in YAML frontmatter,
in the small subset `setup.sh` reads (a one-line value, `[a, b]`, a block of
`- item` lines, or a `|` block):

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

## step 5 — report

- the kind of copy, the upstream source and commit (short), and the files
  written, grouped by skill;
- the facts that came from the developer, with the AGENTS.md lines to add;
- the next step: review `git status` and the diff, then commit `.agents/` and
  `.claude/skills` in one commit;
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

It touches only the files the lock records, plus the new upstream files of
the profile's skills and connected ids; a skill under `kept`, and anything the
project added itself, is never touched. Per file:

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

"Upstream changed" is decided on the raw upstream files, never on rendered
ones, so a profile edit never passes for an upstream change. A conflict is
left untouched: the script prints the rendered base and upstream versions
and its conflict-marked attempt. Show the developer each conflict and each
`ask-*` file, write what they choose, then write the lock:
`setup.sh lock .agents/skills-profile.md <new>`. The script writes the lock
itself only when nothing is left to decide.

A new upstream skill is offered (`add <skill>`), not added; a new upstream
asset id is listed, not connected. With no upstream change (`<new>` equals
`<old>`), `update` still rewrites the facts blocks from the profile: editing
the profile and running `update` is how a fact changes.

**Detached copy.** There is no base to merge from. Read the facts back from
the facts blocks into a temporary profile, render each upstream skill with it
into a temporary folder, and show `git diff --no-index <project skill>
<rendered skill>` skill by skill, summarising what upstream changed. Apply
only what the developer picks, by editing the project's file; never overwrite
it whole.

## connect, disconnect

Check the id is in the anatomy's id table. Managed: add it to (or remove it
from) the profile's `assets`, then, with the clone at the lock's commit:

```bash
${CLAUDE_SKILL_DIR}/scripts/setup.sh assets .agents/skills-profile.md <tmp>/.agents/skills
${CLAUDE_SKILL_DIR}/scripts/setup.sh lock .agents/skills-profile.md <old>
```

It copies in the connected files that are missing, removes unconnected ones
(an edited one is listed, not removed: ask about it), rewrites each
`assets/index.md` and each facts block's assets line. Detached: copy or
remove the asset files by hand (ask before removing any) and edit the assets
line.

## add, remove

`add <skill>` (managed): add it to the profile's `skills` (and take it out of
`kept`), `render` it with the clone at the lock's commit, then rerender every
other installed skill, so their skill-names rows name it as `/<skill>`, and
write the lock:

```bash
${CLAUDE_SKILL_DIR}/scripts/setup.sh render .agents/skills-profile.md <tmp>/.agents/skills <skill>
${CLAUDE_SKILL_DIR}/scripts/setup.sh rerender .agents/skills-profile.md <tmp>/.agents/skills
${CLAUDE_SKILL_DIR}/scripts/setup.sh lock .agents/skills-profile.md <old>
```

`remove <skill>`: show the edits the project made to it (files whose hash
differs from the lock), then delete `.agents/skills/<skill>/`, take it out of
the profile, rerender the others (their rows now name it
`/sample-skills:<skill>`) and write the lock. Name each installed skill that
calls the removed one. Detached: render or delete the skill the same way,
then edit the skill-names row in every other skill by hand.

The Arrow of Intent is part of every skill's core; there is nothing to
switch it off. `setup-skills` itself is never copied into a project.
