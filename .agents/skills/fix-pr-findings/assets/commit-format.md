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
fix: cancel subscriptions and controllers in dispose (PR #9 high #2, medium #3)

Addresses review findings from PR #9:
- High #2: StreamSubscription leak in PdfViewerState
- Medium #3: AnimationController not disposed in GridOverlayState

Both resources cancelled in dispose() per Flutter widget lifecycle.

Ref: https://github.com/{owner}/{repo}/pull/9#discussion_r188675
Ref: https://github.com/{owner}/{repo}/pull/9#discussion_r188684
```
