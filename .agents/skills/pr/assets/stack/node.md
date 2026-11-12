# Node

## What changed

`package.json` cannot hold the dependency-check record, so it lives elsewhere
(where the dependency policy says). When the PR adds or upgrades a package,
add a line: `Dependencies: <package@version>, recorded in <the record's
file>`, so the reviewer can find the check.
