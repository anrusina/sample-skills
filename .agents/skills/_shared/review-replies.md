# Review replies

`/review-pr`, `/fix-pr-findings` and `/pre-merge` hand a pull request's
findings to each other through replies on GitHub. Each reply starts with one
of these prefixes, word for word: the other skills match on them.

| Reply | Written by | Means |
|---|---|---|
| `Addressed in <sha> — <what changed>.` | fix-pr-findings | fixed in `<sha>` |
| `Tracked in #<N> — <why it can't be fixed here>.` | fix-pr-findings, pre-merge | deferred to an open issue that covers it |
| `Captured as #<N> — <why it can't be fixed here>.` | fix-pr-findings | deferred to an issue created for it |
| `Left as-is: <reason>.` | fix-pr-findings | the developer chose not to change it |
| `Verified fixed in <sha> — <what>` | review-pr | the fix holds; resolved |
| `Verified tracked in #<N>` | review-pr | the issue covers what is left; resolved |
| `Accepted as left` | review-pr | resolved |
| `Reopened: <what is still wrong>` | review-pr | a resolved thread is not fixed; unresolved |
| `Not fixed: <what is still wrong>` | review-pr | the claimed fix doesn't hold |
| `Not tracked: <what is left uncovered>` | review-pr | the issue is closed or misses part |

- Only `/review-pr` resolves or unresolves a thread, and it replies first:
  every agent posts as the same account, so the reply is the only record of
  who decided what.
- A finding with no thread (an *Outside the diff* finding in a review
  summary) gets the same reply as a PR conversation comment that names it,
  e.g. `Addressed in <sha> — outside-diff finding #<F>: <what changed>.` or
  `Left as-is: outside-diff finding #<F> — <reason>.` Nothing is resolved.

```bash
# reply on a thread (to its first comment)
gh api repos/{owner}/{repo}/pulls/<pr>/comments/<comment databaseId>/replies -f body='<reply>'
# a finding with no thread
gh pr comment <pr> --body '<reply>'
# resolve (review-pr only; unresolveReviewThread to reopen)
gh api graphql -f id=<thread id> -f query='mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { isResolved } } }'
```

`gh` fills `{owner}` and `{repo}` from the current checkout.
