# Commit format

```
fix: <concise description> (PR #<number> <severity> #<finding>)

Addresses review finding from PR #<number>:
- <Severity> #<finding>: <one-line summary>

<What changed and why.>

Ref: <discussion URL>
```

When one fix covers multiple findings:

```
fix: release listeners and timers on teardown (PR #9 high #2, medium #3)

Addresses review findings from PR #9:
- High #2: event listener leak in CheckoutView
- Medium #3: retry timer not cancelled in SessionRefresher

Both are released in their owner's teardown hook, so neither fires
after the view or service is gone.

Ref: https://github.com/<owner/name>/pull/9#discussion_r188675
Ref: https://github.com/<owner/name>/pull/9#discussion_r188684
```

`<owner/name>` is the run-time repository, `gh repo view --json nameWithOwner -q .nameWithOwner` — copy the discussion URL from the finding rather than building it by hand.

No AI attribution trailer unless `AGENTS.md` asks for one.
