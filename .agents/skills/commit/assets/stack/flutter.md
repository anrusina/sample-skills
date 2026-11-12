# Flutter / Dart

## Scratch paths

Never staged: `.dart_tool/`, `build/`, `.flutter-plugins`, `.flutter-plugins-dependencies`.

## Quality gates

- Format fix: `dart format .` (it writes; `dart format --set-exit-if-changed .` is the checking form).
- Suppression forms, never added on your own initiative: `// ignore: <rule>`, `// ignore_for_file: <rule>`, and a rule set to `false` or a path under `analyzer: exclude:` in `analysis_options.yaml`.

## Dependency registry

| Manifest | Publish date of `<x.y.z>` | Source repository |
|---|---|---|
| `pubspec.yaml` | `curl -s https://pub.dev/api/packages/<name> \| jq -r '.versions[] \| select(.version == "<x.y.z>") \| .published'` | same response: `jq -r '.latest.pubspec.repository // .latest.pubspec.homepage'` |

Record: a `# Checked <today>: …` comment directly above the dependency line in `pubspec.yaml`.
