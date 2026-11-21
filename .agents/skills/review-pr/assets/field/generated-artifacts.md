# Generated artifacts committed with their sources

## Review checks

- Generated outputs (the output paths AGENTS.md names) are binary or machine-written: check that they changed when their sources did, and only then, but never review their contents line by line.
- A source change with no matching output change, or an output change with no source change in the PR, is at least **High**: the committed outputs no longer match what the build makes.
- When the PR changes a generator that produces outputs only on demand (a template or export step outside the main gate), run that step in `<wt>` and check `git -C <wt> status --short` stays empty; anything it lists is a finding.

## Inline comments

- End every Prompt for AI, and each severity's batch prompt, with "Run the project's quality gates after changes and stage the regenerated outputs." in place of the plain closing line.

## Verification

- A row for any on-demand regeneration run in the review, and whether it left the tree unchanged.
