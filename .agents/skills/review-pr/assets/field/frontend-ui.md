# Front-end UI (theme, tokens, layout)

## Review checks

- Apply every theming and layout rule AGENTS.md states. Design values (colors, sizes, spacing, radii, font weights, icons, durations) come from the theme layer AGENTS.md names, never from a literal in a component. Where a guard script enforces this, its result is in Verification; check what it cannot see: inline `style` attributes, SVG `fill` and `stroke` values, styles outside the token block, new style files.
- A token change is made in every theme the project ships and keeps text contrast in each.
- Layout at every width AGENTS.md lists (or the narrowest phone width when it lists none): no horizontal scroll, no fixed size that clips text, nothing reachable only on hover.
- A hard-coded design value is at least **High**; a layout problem at a single width is **Medium**.
- Look-and-feel is the design system's concern: judge a change against the theme and the catalog, not against personal taste.

## Verification

- A row for the widths and themes the changed screens or pages were looked at in, or "not run" with the reason.
