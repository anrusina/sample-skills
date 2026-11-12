---
name: setup-skills
description: "Copy the sample-skills into the current project and tailor them: write the project's facts into each skill, keep only the stack and field assets it uses, and later update the copy from upstream, connect or disconnect an asset, or add or remove a skill. Trigger: /setup-skills [install|update|connect <id>|disconnect <id>|add <skill>|remove <skill>] [--dry-run]."
disable-model-invocation: true
allowed-tools:
  - Bash(git *)
  - Bash(gh repo *)
  - Bash(gh api *)
  - Bash(mktemp *)
  - Bash(mkdir -p *)
  - Bash(ln -s ../.agents/skills .claude/skills)
  - Bash(ls *)
---

You bring the generic sample-skills into a project as the project's own copy,
and keep that copy current. The generic skills (from the plugin, run as
`/sample-skills:<skill>`) work out every project fact at run time. A project
copy has its facts written in and only the assets it uses, so it runs as
`/<skill>`, looks nothing up, and is the project's to tailor.

How a skill is built (the facts block, slots, assets and their ids) is set out
in `docs/skill-anatomy.md` of the source repository. Read it from the clone in
step 1 before writing anything.

Nothing here commits. Every run ends with the files written and a summary; the
developer reviews the diff and commits it (with `/commit` or by hand).

## input

`$ARGUMENTS`:

| Argument | Does |
|---|---|
| empty or `install` | first copy into this project |
| `update` | bring a managed copy up to the latest upstream; also rewrites every facts block from the profile |
| `connect <id>` / `disconnect <id>` | add or remove one stack or field asset across all installed skills |
| `add <skill>` / `remove <skill>` | add or remove one skill |
| `--dry-run` (with any of the above) | do everything up to writing, show what would change, write nothing |
| `--source <owner/repo>[@<ref>]` | take upstream from a fork or a ref instead of `anrusina/sample-skills` at its default branch |

Anything else: print this table and stop.

## the two kinds of copy

Ask which one the developer wants at install (step 4). Both write the facts
into each skill; they differ in what stays the source of truth.

- **Managed.** The facts live in `.agents/skills-profile.md`, and
  `.agents/skills-lock.json` records the upstream commit and a hash of every
  file written. `/setup-skills update` can then bring in upstream changes,
  merging them with the project's own edits, and an edit to the profile
  reaches every skill on the next update. Choose this to keep receiving
  upstream improvements.
- **Detached.** No profile and no lock: the facts are written into each skill
  and the copy is the project's from then on, to edit freely. `update` can
  still compare it with upstream and propose changes skill by skill, but
  cannot merge on its own. Choose this when the project will reshape the
  skills to its own needs.

Every facts block in a project copy starts with a line saying which kind it is.

## step 0 — preconditions

- The current folder is a git checkout: `git rev-parse --show-toplevel`. Work
  at its top level from here on.
- Read the project's `AGENTS.md` (or `CLAUDE.md` when there is no AGENTS.md).
- Note what is already there: `ls .agents/skills .claude/skills`, and whether
  `.agents/skills-profile.md` and `.agents/skills-lock.json` exist.
  - `install` with a lock present → it is already managed; say so and offer
    `update` instead.
  - `update`, `connect`, `disconnect`, `add`, `remove` with no lock → a
    detached copy (or none). See each step for what that changes.

## step 1 — fetch upstream

Clone the source into a fresh temporary folder (always a clone, never the
plugin's own files, so the commit is exact and older versions can be read):

```bash
mktemp -d
```

```bash
git clone --quiet https://github.com/anrusina/sample-skills.git <tmp>
git -C <tmp> rev-parse HEAD
```

With `--source owner/repo@ref`, clone that repository and `git -C <tmp>
checkout --quiet <ref>`. Note the commit as `<new>`. Read
`<tmp>/docs/skill-anatomy.md`.

The upstream skills are `<tmp>/.agents/skills/<name>/`, every folder there
except `setup-skills` (this skill is never copied into a project).

## step 2 — work out the facts

Only for `install` (an `update` reads them from the profile; a detached
`update` reads them back from the existing facts blocks).

Work out each fact in the anatomy's table, and note where each value came
from (`gh`, an AGENTS.md section by name, a manifest, the Makefile, an
existing skill, or "not found"). The skills' own rules name the section a
fact *usually* lives in; at install, look wider, because a value found here is
written into every skill and never looked up again:

- `<repo>`, `<base>`: from `gh repo view` (through the wrapper, once known).
- wrapper: AGENTS.md as a whole (a "run tools through …" rule anywhere, not
  only in the build section), and the tool-version file: a `mise.toml` or
  `.mise.toml` means `mise exec --`, unless AGENTS.md says otherwise.
- gates: AGENTS.md's build section. When it lists both separate commands and
  one command that runs them all (a `make check`), the gates fact is the one
  command, with the separate ones noted as what it runs. Read the Makefile or
  task runner to confirm what it runs.
- format fix: the write-mode formatter when the format gate only checks
  (`--check`, `--set-exit-if-changed`, `--diff`). When the format gate itself
  writes in place, format fix is `none (the format gate writes)`.
- setup: AGENTS.md *Worktree setup*; without one, any section that says what a
  fresh checkout or worktree needs (code generation, dependency install,
  trusting a tool-version file).
- build-input docs: AGENTS.md *Project structure*, and any content folder the
  build reads Markdown from.
- every optional fact in the anatomy's list of optional rows (pre-merge checks,
  releases, project board, milestones, feedback, dependency policy and the
  rest). Store each as the **whole** of what the section says, not a pointer
  to it: each skill's rule takes the part it needs at render time (step 5).
- **the project's existing skills.** If `.agents/skills/` or `.claude/skills/`
  already holds skills, read every one that upstream would replace. They often
  hold facts AGENTS.md lacks: a wrapper-prefixed `gh`, a version-bump target,
  fixture links, setup steps, a board number, milestone names. Take each such
  fact into the proposal with `From: existing skill <name>`. A fact that
  exists only in a skill about to be replaced is otherwise lost.
- assets: each stack id whose marker file is at the repo root, and each field
  id whose condition holds, from the anatomy's id table. Read the conditions
  as written: `web-site` needs rules for search, links, claims or a budget;
  `fonts` needs a font build, not bundled fonts.
- skills: all upstream skills by default.

## step 3 — when a required fact is missing

Three facts are required: `<repo>`, `<base>` and the gates. If one was not
found, ask for it in the step 4 proposal; never guess a gate command. Every
other fact may be `none`. For setup, propose the loaded stack assets' typical
steps (start-task's stack assets, *Setup* section) as a suggestion the
developer confirms, never as a found value. Offer to record what the developer gives you in
AGENTS.md as well (in the section the rule names), so people and other tools
see it too.

## step 4 — propose, and ask once

Show one proposal and ask for one answer:

1. **Facts**: a table `Fact | Value | From`. Mark the ones still missing.
2. **Assets**: connected ids, and each id not connected with its condition, so
   the developer can add or drop one.
3. **Skills**: the list to install. Name anything worth dropping: the
   coordinator roles (`coding-master`, `managerial`) are for the Claude
   desktop app; `feedback-review` assumes a feedback inbox.
4. **Kind of copy**: managed (recommended when the project wants upstream
   updates) or detached.
5. **Conflicts**: each upstream skill whose name already exists in
   `.agents/skills/` or `.claude/skills/` (count it once when
   `.claude/skills` is a symlink to `.agents/skills`), with the choice of
   keeping the project's skill (the default: skip upstream's) or replacing it.
   For a replacement, summarise what the project's version has that
   upstream's lacks (rules, steps, facts) rather than pasting a whole diff, and
   say which of those step 2 carried into the facts.

With `--dry-run`, show the proposal and the file list step 5 would write with
the defaults (managed copy, every proposed skill and asset, conflicts kept),
remove the temporary clone, and stop.

## step 5 — write the copy

For each chosen skill, from `<tmp>/.agents/skills/<name>/`:

0. When replacing a project skill, delete its folder first, so no file of
   the old version is left behind.
1. Copy every file except `assets/stack/*` and `assets/field/*`. Copy
   `assets/index.md` with the rows for unconnected ids removed; if no asset
   row is left, keep only what it says about other files (templates), or
   drop it when that is nothing.
2. Copy `assets/stack/<id>.md` and `assets/field/<id>.md` for each connected
   id that this skill has. Many skills have none for a given id; that is
   expected.
3. **Render the facts block** in `SKILL.md`, replacing everything between
   `<!-- facts:begin -->` and `<!-- facts:end -->`:
   - first line: `Written by /setup-skills from .agents/skills-profile.md
     (managed copy: edit the profile and run /setup-skills update, not this
     block).` or, for a detached copy, `Written by /setup-skills when this
     copy was made. This is the project's own copy: edit these values here.`
   - the same table, header `| Fact | Value |`, with the same rows as the
     generic block (only the facts this skill uses), each value written in:
     commands in backticks, several gates or setup steps as a numbered list in
     the cell. An empty optional fact is `none` followed by the rule's own
     parenthesis after "or none", whatever it says (`none (skip step 8.1)`).
     A rule whose fallback is a run-time look-up or a question ("without that
     section, look them up as in step 0", "ask once") keeps that fallback
     after `none`. A run-time row (its rule says "read at run time", such as
     `labels`) keeps its rule unchanged. When a stored fact is broader than a
     skill's rule asks for (the whole *Milestones* section, where start-task
     needs only which are active), write the part that rule names.
   - `skill names`: `/<name>` for each skill installed in this copy, and
     `/sample-skills:<name>` for one left out (still reachable from the
     plugin). coding-master lists one form per relayed skill.
   - `assets`: the ids connected **and** present in this skill, or `none`.
   - drop the generic paragraphs about finding facts and AGENTS.md roles.
   - if the skill has assets, end with `Assets: every file under
     assets/stack/ and assets/field/ applies (<ids>).`, or `Assets: none
     connected.`, listing only the ids present in this skill.
4. Remove the description's closing sentence `Generic template: a project's
   own \`<name>\` skill takes precedence.`
4b. **Adapt `allowed-tools`** to the project, so its commands run without a
   permission prompt: with a wrapper, add the wrapper-prefixed form beside
   each tool pattern (`Bash(mise exec -- gh pr *)` beside `Bash(gh pr *)`);
   add the gate, format-fix and setup commands to the skills that run them
   (commit, review-pr, pre-merge, start-task, fix-pr-findings, doc-audit-full).
   Never remove a pattern, and never add a broader one than the command
   needs.
5. Write into `.agents/skills/<name>/`. Never write outside `.agents/skills/`,
   `.agents/skills-profile.md`, `.agents/skills-lock.json` and the symlink
   below.

Then:

- **Claude Code discovery.** If `.claude/skills` doesn't exist: `mkdir -p
  .claude` and `ln -s ../.agents/skills .claude/skills`. If it is already a
  symlink to `../.agents/skills`, leave it. If it is a real folder, don't
  touch it: name the skills it holds that would now be shadowed
  or duplicated, and leave the decision to the developer.
- **Managed only.** Write `.agents/skills-profile.md` (format below) and
  `.agents/skills-lock.json`:

  ```json
  {
    "source": "anrusina/sample-skills",
    "commit": "<new>",
    "files": { ".agents/skills/commit/SKILL.md": "<git hash-object of the written file>" }
  }
  ```

  with one `files` entry per file written. Use `git hash-object <file>` for
  each hash: it gives the same result on every platform.

### the profile

`.agents/skills-profile.md` is Markdown with the values in YAML frontmatter,
so a person can read and edit it:

```markdown
---
source: anrusina/sample-skills
skills: [arrow-check, commit, commit-and-pr, …]
assets: [python, generated-artifacts]
facts:
  repo: acme/widgets
  base: main
  wrapper: mise exec --
  gates: [make check]
  format-fix: none
  setup: [python3 -m venv .venv, .venv/bin/pip install -r requirements.txt]
  build-input-docs: none
  source-and-test-dirs: [src/, tests/]
  dependency-policy: AGENTS.md → Security → Dependency policy
  pre-merge-checks: none
  fixtures: none
  releases: none
  manual-workflows: none
  project-board: none
  milestones: none
  backlog-milestone: none
  feedback-labels: none
  inbox-milestone: none
  blast-radius-map: none
---

The project facts every skill in `.agents/skills/` was written with.
Edit a value here, then run `/setup-skills update` to write it into the
skills. Run `/setup-skills connect <id>` or `disconnect <id>` to change the
assets.
```

## step 6 — report

- the kind of copy, the upstream commit (short), and the files written, grouped
  by skill;
- facts that came from the developer rather than the repo, and whether they
  were recorded in AGENTS.md;
- the next step: review `git status` and the diff, then commit
  `.agents/`, `.claude/skills` and any AGENTS.md change in one commit;
- that the plugin's skills stay reachable as `/sample-skills:<skill>`, and the
  project's copies now answer to `/<skill>`.

Remove the temporary clone.

## update

**Managed copy.** Read the profile and the lock; fetch upstream (step 1). Let
`<old>` be the lock's commit.

For every file the copy holds, plus every upstream file that a chosen skill
and a connected id would now bring:

- `ours`: the project's file, or nothing if it is new upstream.
- `base`: the upstream file at `<old>` (`git -C <tmp> show <old>:<path>`),
  rendered with the **current** profile (step 5 rules), or nothing if it is
  new.
- `theirs`: the upstream file at `<new>`, rendered with the current profile,
  or nothing if upstream removed it.

Rendering all three with the current profile makes a profile edit reach the
facts blocks without ever looking like a conflict. Then, per file:

| Case | Action |
|---|---|
| `ours` hash equals the lock's hash (never edited) | write `theirs` |
| `theirs` equals `base` (no upstream change) | keep `ours`; rewrite only its facts block from the profile |
| new upstream file | write it |
| removed upstream, never edited | delete it |
| removed upstream, edited | ask: keep it or delete it |
| both changed | `git merge-file -p <ours> <base> <theirs>` on temporary copies; a clean merge is written; a conflict is shown with the three versions and the developer decides |

A new upstream skill is offered, not added. A new upstream asset id is
listed, not connected. Write the new lock (`commit: <new>`, fresh hashes) and
report what was updated, merged, kept and left in conflict.

`update` with no upstream change (`<new>` equals `<old>`) still rewrites the
facts blocks from the profile, so editing the profile and running `update` is
how a fact changes.

**Detached copy.** There is no base to merge from. Read the facts back from
the existing facts blocks, render each upstream skill with them, and show
`git diff --no-index <project file> <rendered upstream>` skill by skill,
summarising what upstream changed. Apply only what the developer picks, by
hand-editing the project's file; never overwrite it whole.

## connect, disconnect

`connect <id>`: check `<id>` is in the anatomy's id table. For each installed
skill that has `assets/stack/<id>.md` or `assets/field/<id>.md` upstream (at
the lock's commit for a managed copy, so versions don't mix; at `<new>` for a
detached one), copy it in, and rewrite that skill's facts-block assets line.
Managed: add the id to the profile and the files to the lock.

`disconnect <id>`: remove those files (ask first for any file whose hash
differs from the lock, or for any file in a detached copy), rewrite the
assets lines, and update the profile and lock.

## add, remove

`add <skill>`: step 5 for that one skill (at the lock's commit for a managed
copy), with the profile's facts and assets. `remove <skill>`: delete
`.agents/skills/<skill>/` after showing any edits the project made to it (by
lock hash), and update the profile and lock. Name any other installed skill
that calls the removed one.

## rules

- Never commit, push, or change anything outside the paths in step 5.
- Never guess a gate command: a missing one is asked for. A setup step not
  found in the project is only ever proposed, for the developer to confirm.
- A file the project edited is never overwritten without a merge or the
  developer's say.
- The Arrow of Intent is part of every skill's core; there is nothing to
  switch it off.
- Never copy `setup-skills` itself into the project.
