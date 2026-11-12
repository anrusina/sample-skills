# PR testing checklist

Used by `/pr` step 6 to write the `## Testing:` section of the PR body. This
file is the generic default; a project tailors it by editing it — for example
to add a manual check on a device, a browser matrix, or a slow suite that only
runs before merge.

## Default

One checkbox per quality gate listed in AGENTS.md *Build and test commands*,
in the order listed, naming the command, then the tests added:

```markdown
## Testing:
- [ ] `<format gate command>` clean
- [ ] `<lint/analyze gate command>` clean
- [ ] `<test gate command>` passes
- Tests added: <test files or test names, with their `@spec` IDs — or "none">
```

Fill the angle slots from AGENTS.md and the diff; never leave one in the PR
body. If AGENTS.md lists no gates, use the commands `/commit` ran for this
branch in this session; if there are none, ask the developer once for the
commands, use them, and tell them to record the commands in AGENTS.md
*Build and test commands*.

## Variations

- **Documentation-only PR** (every changed path is Markdown or under
  `docs/`): replace the gate items with
  `- [ ] Docs-only change — quality gates not run`.
- **Behaviour without an automated test** (a UI flow, an integration only
  testable by hand): add `- [ ] Manually checked: <what was exercised, and
  where>` and say why no automated test covers it.
- **Extra pre-merge checks**: if AGENTS.md has a *Pre-merge checks* section,
  add one unticked item per check, marked `(runs at /pre-merge)`, so the
  reviewer knows they are still to come.
