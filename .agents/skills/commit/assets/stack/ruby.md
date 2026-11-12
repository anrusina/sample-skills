# Ruby

## Scratch paths

Never staged: `.bundle/`, `vendor/bundle/`, `coverage/`, `tmp/`, `log/` contents that git does not track.

## Quality gates

- Format fix: `rubocop -a` (or the project's formatter in write mode).
- Suppression forms, never added on your own initiative: `# rubocop:disable`, `# rubocop:todo`, an entry added to `.rubocop_todo.yml` or an `Exclude:` list.

## Dependency registry

| Manifest | Publish date of `<x.y.z>` | Source repository |
|---|---|---|
| `Gemfile`, `*.gemspec` | `curl -s https://rubygems.org/api/v1/versions/<name>.json \| jq -r '.[] \| select(.number == "<x.y.z>") \| .created_at'` | `curl -s https://rubygems.org/api/v1/gems/<name>.json \| jq -r '.source_code_uri // .homepage_uri'` |

Record: a `# Checked <today>: …` comment directly above the `gem` line.
