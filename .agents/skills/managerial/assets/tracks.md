# Default tracks and track format

The default for a project whose AGENTS.md doesn't define its own delivery
tracks or track format. Replace it in a project copy to fit the project.

## Tracks

Two app tracks for the coding sessions:

- **Track A**: core logic and data.
- **Track B**: the app surface and release, including the owner's tasks.

Separate work (a website, a design asset) stays outside these two, in the
Outside table. If the project's subsystems split differently, agree the two
tracks' scopes with the owner when framing the first phase.

## Track format

```
Track A: ~~#12 (login form)~~ -> 🔄#15 (session refresh) · [#17 (cart model) -> #18 (cart sync)] -> ⏸ Wait for #20 (API merged) -> 👤#22 (pricing rules)
```

- Steps are joined with `->`, parallel items with ` · `. A parallel item
  may be a chain in brackets: `[#a -> #b] · #c`.
- A wait is its own step: `-> ⏸ Wait for #N (what) ->`.
- Each ticket gets a 2–3 word label. A 👤 prefix marks a step that needs the
  owner's active involvement: their own task or a `curated` ticket. Agent
  work the owner only checks by hand is `auto` and gets none.
- 🔄 is a prefix on in-progress items, in the tracks and the Outside table
  alike (`🔄#15`). Keep it in sync with the progress doc's in-progress
  markers, and drop it when the item is struck.
- Done items are struck through (`~~…~~`); the arrows aren't.
- Stage contents are bare numbers.
- Only the app tracks. Website and other side work run outside them.
