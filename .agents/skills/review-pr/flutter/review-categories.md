# Flutter / Dart review categories

Load this file when reviewing a Flutter or Dart project. These categories extend the generic review categories in the main skill.

## Flutter specifics

- Expensive work in `build()` (layout calculations, I/O, heavy computation)
- Missing `const` constructors on widgets with no mutable state
- Leaked `StreamSubscription` or `AnimationController` (not cancelled/disposed in `dispose()`)
- Unnecessary widget rebuilds (`setState` scope too broad, missing `const`, provider reads in wrong widget)
- `setState` called after `dispose()`

## Architecture layer rules (Riverpod + go_router)

Verify each of the following:

| Rule | What to check |
| --- | --- |
| `domain/` purity | Pure Dart only — no Flutter, no drift, no http, no external packages |
| `data/` boundary | May use drift/http/platform plugins — no Flutter widgets, no other `features/` |
| `presentation/` boundary | May use Flutter + Riverpod + `core/` — never imports another `features/` |
| Inter-feature isolation | `features/X` never imports `features/Y` — cross-feature only through `core/` providers or shared domain interfaces |
| Route isolation | `go_router` imported only inside `lib/core/router/` — never in feature code |
| Service isolation | External services used only through `lib/core/services/` interfaces — never instantiated directly in feature code |
| Theme tokens | No raw `Color(0x...)`, `EdgeInsets.all(<number>)`, or hardcoded text styles — always `colorScheme.*`, `AppSpacing.*`, `textTheme.*` |
| Localisation | No hardcoded user-visible strings — always via the localisation system (e.g. `AppLocalizations.of(context)!.*`) |

## Blast radius classification (Flutter)

| Blast radius | Emoji | Examples |
| --- | --- | --- |
| Isolated | ✅ | Single widget, single test, config constant |
| Localised | 🔵 | Private method, one BLoC/Notifier, one screen |
| Cross-cutting | ⚠️ | Notifier event/state interface change, shared provider, spec update |
| Systemic | 🔴 | Storage schema, navigation model, shared domain entity, core service interface |
