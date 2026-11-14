# Go

## Scratch paths

Never staged: built binaries and `bin/` output that git does not track, `coverage.out`.

## Quality gates

- Format fix: `gofmt -w .` (or `go fmt ./...`); the checking form is `gofmt -l .`.
- Suppression forms, never added on your own initiative: `//nolint`, `//nolint:<linter>`, an exclusion added to `.golangci.yml`.

## Dependency registry

| Manifest | Publish date of `<vX.Y.Z>` | Source repository |
|---|---|---|
| `go.mod` | `curl -s https://proxy.golang.org/<module>/@v/<vX.Y.Z>.info \| jq -r '.Time'` | usually the module path itself (`github.com/<owner>/<repo>`); for a vanity path, `curl -s "https://<module>?go-get=1"` and read the `go-import` meta tag |

Module paths with capital letters are escaped in proxy URLs: each uppercase letter becomes `!` plus its lowercase form (`github.com/Azure/x` → `github.com/!azure/x`).

Record: a `// Checked <today>: …` comment directly above the `require` line in `go.mod`.
