---
name: pr
description: "Open a pull request from the current branch's pushed commits: writes the title and a body with what changed, the issue links (Closes, or Ref when an acceptance criterion is unmet), the specs it implements and a testing checklist, then adds existing labels and assigns it. Use when commits are pushed and need a PR: 'open a PR', 'raise a pull request', or the second half of /commit-and-pr. Not for committing (/commit) or reviewing a PR (/review-pr). Generic copy: if a project skill named `pr` is also listed, use that one instead."
model: haiku
allowed-tools:
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git rev-parse *)
  - Bash(git grep *)
  - Bash(git symbolic-ref *)
  - Bash(git branch *)
  - Bash(gh pr create *)
  - Bash(gh pr edit *)
  - Bash(gh pr view *)
  - Bash(gh api *)
  - Bash(gh label *)
  - Bash(gh repo *)
  - Bash(cat *)
  - Bash(mktemp *)
  - Bash(${CLAUDE_SKILL_DIR}/../_shared/scripts/spec-ids.sh *)
---

You synthesise this branch's commits into a clear pull request, so the developer writes no boilerplate.

> After the PR is open, use `/review-pr` for code review and `/pre-merge` for thread triage before merging.

## Project facts

<!-- facts:begin -->
This is the generic copy: work out the facts below as
[../_shared/facts.md](../_shared/facts.md) says. A row marked *shared* takes
its rule from there.

| Fact | How to find it |
|---|---|
| `<base>` | *shared* |
| wrapper | *shared* |
| gates | *shared* |
| build-input docs | *shared* |
| source and test dirs | AGENTS.md *Project structure*: the source and test directories, or none (then any changed file that is not Markdown, not under `docs/`, and not tooling, CI or editor config counts as source) |
| pre-merge checks | AGENTS.md *Pre-merge checks*: checks that run only at `/pre-merge`, or none |
| skill names | *shared* |
| assets | *shared* |
<!-- facts:end -->

## setup

```bash
git branch --show-current
```

Check for an existing open PR first — if one exists, report its URL and stop:
```bash
gh pr view --json url,state -q 'select(.state == "OPEN") | .url' 2>/dev/null
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

4.5. **Issue-coverage check** — skip it if the PR has no `Closes #N`. For each `Closes #N` from step 4, fetch the issue body and all its comments (`gh` fills `{owner}` and `{repo}`; write the issue number in):
   ```bash
   gh api repos/{owner}/{repo}/issues/<N> --jq '{title, body}'
   gh api repos/{owner}/{repo}/issues/<N>/comments --paginate --jq '.[] | .body + "\n---"'
   ```
   Extract acceptance criteria from the body **and every comment** (later requirements and edge cases count equally): `- [ ]` task list items and content under "Acceptance criteria", "Done when", or "Requirements" headers. Review the commit diff against each criterion. Do not stop to ask. List every item that appears unaddressed in a `### Out of scope` section of the PR body:
   - If the session already agreed the exclusion (e.g. work handed to another issue), say so, link where it went, and leave that issue's reference as `Closes #N`.
   - Otherwise mark it `**Not covered — needs a decision**`, and change that issue's reference in `## Related issues:` from `Closes #N` to `Ref #N`.

   Name any downgraded or not-covered items in the final report next to the PR URL.

5. **`## Arrow of Intent:`** check whether the diff contains source or test files (the `source and test dirs` fact):
   ```bash
   git diff --name-only origin/<base>...HEAD
   ```
   - **No source or test changes** (tooling, docs, config only) → omit this section entirely.
   - **Source or test changes present** → find the spec IDs the branch tags, from the diff itself, and HLD references in the commit bodies:
     ```bash
     ${CLAUDE_SKILL_DIR}/../_shared/scripts/spec-ids.sh --wrap '<wrapper>' added origin/<base>
     ```
     It prints each ID tagged on a line the branch adds, outside docs, skills and Markdown (pass the source and test dirs as arguments to narrow it).
     - If it prints at least one ID, list all spec IDs covered and the HLD section.
     - If **no ID and no HLD reference** are found — **stop and ask the developer**, and do not create the PR until they supply it or confirm the omission is intentional:
       > "This PR touches source code but no `@spec` tags or HLD references were found in its changes. Please provide: the HLD section this change falls under, and the EARS spec IDs it implements (create them first if they don't exist yet)."

6. **`## Testing:`** build this section as [assets/testing-checklist.md](assets/testing-checklist.md) describes, adding the *Testing checklist* lines of each loaded asset that apply to the diff.

7. **Create** — write the body to a fresh `mktemp` file (never a fixed `/tmp` name) and create and assign the PR in the same call, so the file is removed even when `gh` fails:
   ```bash
   body=$(mktemp) && trap 'rm -f "$body"' EXIT
   cat > "$body" <<'PR_BODY'
   <the PR body>
   PR_BODY
   gh pr create --title "<title>" --body-file "$body" --base <base> --assignee "$(gh api user -q '.login')"
   ```

8. **Labels** — apply from existing labels only (`gh label list --limit 100`); never create one:

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

- Do not close or resolve PR threads: that is the next review's call.
- No AI-attribution footers unless AGENTS.md asks for one.
