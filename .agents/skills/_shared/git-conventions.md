# Git conventions

## Branch names

Every branch carries its GitHub issue number:

```
feature-<N>/<3-5-word-slug>   # new functionality
fix-<N>/<3-5-word-slug>        # bug fixes
spike-<N>/<3-5-word-slug>      # research / investigation
docs-<N>/<3-5-word-slug>       # documentation only
```

plus any prefix a loaded asset's *Commit message* section adds.

## Commit messages

**Subject:** `[#N] type: what changed, in the imperative`, at most 72
characters. `[#N]` is the issue number from the branch name
(`<prefix>-42/...` → `[#42]`), left out when the branch has none; a commit
that unavoidably covers several issues lists them all
(`[#12][#13] feat: ...`). The type is one of these, plus any a loaded asset's
*Commit message* section adds:

| Type | When |
|---|---|
| `feat` | New functionality |
| `fix` | Bug fix |
| `docs` | Documentation or spec only |
| `chore` | Tooling, config, dependencies |
| `test` | Tests only |
| `refactor` | Refactor without behaviour change |

**Body:** `Work done:` and 1–5 bullets: imperative, identifiers in
backticks, what and why rather than how, with the `@spec` ID a bullet
implements.

No AI attribution trailer (`Co-Authored-By:` or similar) unless AGENTS.md
asks for one.

```
[#12] feat: clear the password field on invalid credentials

Work done:
- Reset `LoginForm.password` when the auth service rejects the credentials  // @spec AUTH-001
- Show the invalid-credentials error inline, next to the form
- Add `LoginFormTest` covering rejected submit and retry  // @spec AUTH-002
```

Write a message to a `mktemp` file with a quoted heredoc and pass the file,
in one shell call: inside `-m "…"` the shell would run every backticked
identifier.

```bash
msg=$(mktemp)
cat > "$msg" <<'MSG_EOF'
<message>
MSG_EOF
git commit -q -F "$msg"; rc=$?; rm -f "$msg"; exit $rc
```
