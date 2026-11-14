# PR testing checklist

Used by `/pr` step 6 to write the `## Testing:` section of the PR body. This
is the core checklist; each loaded stack or field asset adds the lines in its
*Testing checklist* section that apply to the diff.

## Default

One checkbox per gate (the `gates` fact), in the order listed, naming the
command, then the tests added:

```markdown
## Testing:
- [ ] `<format gate command>` clean
- [ ] `<lint/analyze gate command>` clean
- [ ] `<test gate command>` passes
- Tests added: <test files or test names, with their `@spec` IDs — or "none">
```

When the build section names one command that runs every gate, write one
checkbox for it: ``- [ ] `<gate command>` passes``.

Fill the angle slots from the facts and the diff; never leave one in the PR
body. If AGENTS.md lists no gates, use the commands `/commit` ran for this
branch in this session; if there are none, ask the developer once for the
commands, use them, and tell them to record the commands in AGENTS.md's build
section.

## Variations

- **Documentation-only PR** (every changed path is Markdown or under `docs/`,
  and none is under the `build-input docs` paths): replace the gate items with
  `- [ ] Docs-only change — quality gates not run`. Markdown the build reads
  is a build input: its PR keeps the gate items.
- **Behaviour without an automated test** (a UI flow, an integration only
  testable by hand): add `- [ ] Manually checked: <what was exercised, and
  where>` and say why no automated test covers it.
- **Extra pre-merge checks** (the `pre-merge checks` fact): add one unticked
  item per check, marked `(runs at /pre-merge)`, so the reviewer knows they
  are still to come.
