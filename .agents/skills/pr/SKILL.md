---
name: pr
description: "Open a pull request from the current branch — synthesises pushed commits into a titled, labelled PR with issue links (Closes #N), Arrow-of-Intent spec coverage, and a testing checklist. Trigger: user or model needs to open a PR after commits are pushed (e.g. \"open a PR\", \"raise a pull request\", \"/pr\", or as the second half of /commit-and-pr). Generic template: a project's own `pr` skill takes precedence."
model: haiku
allowed-tools:
  - Bash(git *)
  - Bash(gh pr *)
  - Bash(gh api *)
  - Bash(gh label *)
  - Bash(gh repo *)
  - Bash(cat *)
  - Bash(mktemp *)
---

You are a GitHub PR assistant for this project. You synthesise commits into a clear pull request — without requiring the developer to write boilerplate.

> After the PR is open, use `/review-pr` for code review and `/pre-merge` for thread triage before merging.

## Project facts

<!-- facts:begin -->
This is the generic copy: no project facts are written into it. Work out each
fact below once, at the start of the run, then write its value literally into
every command that needs it. Each Bash call starts a fresh shell, so a variable
set in one call is empty in the next; never carry a value across calls in a
shell variable.

| Fact | How to find it |
|---|---|
| `<base>` | `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`; if that fails, `git symbolic-ref --short refs/remotes/origin/HEAD \| sed 's\|^origin/\|\|'` |
| wrapper | AGENTS.md build section: the prefix the toolchain runs through (a version manager's exec command, for example), or none. Run the gates, and each tool the wrapper provides (the tools its config file lists), through it; pass it to this skill's scripts as `--wrap '<wrapper>'`; run every other command bare, so it matches `allowed-tools` |
| gates | AGENTS.md build section: the format, lint/analyze and test commands, in order, or the one command that runs them all |
| build-input docs | AGENTS.md *Project structure*: Markdown the build reads, or none. Whatever AGENTS.md says, Markdown or MDX inside the source tree that the build reads (content collections, MDX pages, a docs site's sources) counts too. A change to any of it runs the gates like code |
| source and test dirs | AGENTS.md *Project structure*: the source and test directories, or none (then any changed file that is not Markdown, not under `docs/`, and not tooling, CI or editor config counts as source) |
| pre-merge checks | AGENTS.md *Pre-merge checks*: checks that run only at `/pre-merge`, or none |
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

## setup

```bash
git branch --show-current
```

Check for an existing open PR first — if one exists, report its URL and stop:
```bash
gh pr view --json url -q '.url' 2>/dev/null
```

Check for a PR body template:
```bash
cat .github/pull_request_template.md 2>/dev/null
```
If the file exists and has content, use it as the PR body template in step 7 instead of the default format.

## create PR

1. **Collect commits:**
   ```bash
   git log origin/<base>..HEAD --oneline
   git log origin/<base>..HEAD --format="%s%n%n%b"
   ```
   Extract every `[#N]` issue reference from commit subjects.

2. **Title:** single commit → use the commit subject verbatim (it already carries `[#N] type:`). Multiple commits → synthesise the theme with format `[#N] type: <theme>` where N and type come from the branch name (`feature-42/...` → `[#42]`, branch prefix `feature` → `feat`). If commits reference multiple issues, list all: `[#12][#13] feat: ...`. Max 72 chars.

3. **`## What changed:`** group by concern — not one bullet per commit:

   | Emoji | Meaning | Emoji | Meaning |
   |---|---|---|---|
   | ✨ | New feature | 🐛 | Bug fix |
   | ♻️ | Refactor | 🧪 | Tests |
   | 📝 | Docs / specs | 🔧 | Tooling / config |

   Then add what the *What changed* section of each loaded asset asks for.

4. **`## Related issues:`**
   - `Closes #N` — every acceptance criterion is covered, or every excluded item is an agreed handoff (see 4.5)
   - `Ref #N` — related but not closed, including an issue with an unagreed, uncovered criterion (see 4.5)
   - Omit section if none

4.5. **Issue-coverage check** — for each `Closes #N` found in step 4, fetch the issue body and all its comments (`gh` fills `{owner}` and `{repo}` from the checkout; write the issue number in):
   ```bash
   gh api repos/{owner}/{repo}/issues/<N> --jq '{title, body}'
   gh api repos/{owner}/{repo}/issues/<N>/comments --paginate --jq '.[] | .body + "\n---"'
   ```
   Extract acceptance criteria from both body **and all comments** — `- [ ]` task list items and content under "Acceptance criteria", "Done when", or "Requirements" headers. Comments may contain requirements or edge cases added after the issue was written; treat them equally. Review the commit diff against each criterion. Do not stop to ask — the developer reviews coverage in the PR. List every item that appears unaddressed in a `### Out of scope` section of the PR body:
   - If the session already agreed the exclusion (e.g. work handed to another issue), say so, link where it went, and leave that issue's reference as `Closes #N`.
   - Otherwise mark it `**Not covered — needs a decision**`, and change that issue's reference in `## Related issues:` from `Closes #N` to `Ref #N` — merging must never auto-close an issue that still has an undecided requirement.

   Name any downgraded or not-covered items in the final report next to the PR URL, so the developer can resolve the item or restore the closing reference deliberately. Skip this check if the PR references no issues with `Closes #N`.

5. **`## Arrow of Intent:`** check whether the diff contains source or test files (the `source and test dirs` fact):
   ```bash
   git diff --name-only origin/<base>...HEAD
   ```
   - **No source or test changes** (tooling, docs, config only) → omit this section entirely.
   - **Source or test changes present** → scan commit bodies for `@spec` tags and HLD references:
     - If at least one `@spec SUBSYSTEM-NNN` tag is found, list all spec IDs covered and the HLD section.
     - If **no `@spec` tags and no HLD reference** are found — **stop and ask the developer:**
       > "This PR touches source code but no `@spec` tags or HLD references were found in the commits. Please provide: the HLD section this change falls under, and the EARS spec IDs it implements (create them first if they don't exist yet)."
     - Do not create the PR until the developer supplies this information or confirms the omission is intentional.

6. **`## Testing:`** build this section as [assets/testing-checklist.md](assets/testing-checklist.md) describes, adding the *Testing checklist* lines of each loaded asset that apply to the diff.

7. **Create** — write the body to a fresh scratch file from `mktemp` (never a fixed `/tmp` name, which two sessions can share) and create the PR in the same call, so the file is removed even when `gh` fails. Assignment happens in the same `gh pr create`, so it is atomic with PR creation:
   ```bash
   body=$(mktemp) && trap 'rm -f "$body"' EXIT
   cat > "$body" <<'PR_BODY'
   <the PR body>
   PR_BODY
   gh pr create --title "<title>" --body-file "$body" --base <base> --assignee "$(gh api user -q '.login')"
   ```

8. **Labels** — apply from existing labels only (`gh label list`); never create one:

   | Signal | Label |
   |---|---|
   | New functionality | `feature` |
   | Bug fix | `bug` |
   | HLD, LLD, specs, docs | `documentation` |
   | Tooling, config, dependencies | `chore` |
   | Performance improvement | `performance` |
   | Security fix or hardening | `security` |

   If the repository names a label differently (`enhancement` for `feature`, say), use the existing one that means the same; if none does, skip that label.

   ```bash
   gh pr edit <number> --add-label "<label>"
   ```

9. Print the PR URL.

## rules

- Resolve the default branch dynamically — never hardcode `main`.
- Do not close or resolve PR threads.
- No AI-attribution footers unless AGENTS.md asks for one.
