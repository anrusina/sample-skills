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
fix: cancel subscriptions and release resources in dispose (PR #9 high #2, medium #3)

Addresses review findings from PR #9:
- High #2: SubscriptionManager leak in PdfViewerState
- Medium #3: AnimationController not released in GridOverlayState

Both resources released in dispose() per component lifecycle contract.

Ref: https://github.com/{owner}/{repo}/pull/9#discussion_r188675
Ref: https://github.com/{owner}/{repo}/pull/9#discussion_r188684
```
