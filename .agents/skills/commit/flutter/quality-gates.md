# Flutter quality gates

Fallback commands when `make check` is unavailable. Run in order — stop and report on first failure:

1. `dart format --output=none --set-exit-if-changed .` — if it fails, run `dart format .`, re-stage edited files (`git add -u`), then continue
2. `flutter analyze` — warnings are acceptable; errors block
3. `flutter test` — any failure blocks

If none of these are available yet (empty project), skip and note it.
