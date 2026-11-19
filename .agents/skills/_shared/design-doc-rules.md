# Design-doc rules

The Arrow of Intent rules the design docs (the HLD, each LLD, each EARS file)
keep. Where AGENTS.md states its own rule on one of these, its rule decides;
these are the default where it says nothing. The skill that applies a rule
says when it applies and how a breach is reported.

1. **Requirements stay downstream.** The HLD cites no EARS file or
   requirement ID. An LLD may link its EARS file and name a namespace such as
   `AUTH-NNN` as a navigation aid, but maps nothing to individual numbered
   IDs or EARS section anchors and keeps no per-ID coverage inventory.

2. **LLD altitude.** An LLD pins no look-and-feel value: a raw color (hex or
   named), a literal pixel or point size, a font name or weight, an icon
   glyph, an animation curve or duration, or exact user-visible wording.
   - Fine: a named design-system token (`errorFieldColor`, `spacing.md`, a
     breakpoint constant), a named text style, an animation constant, a
     localization key, or a plain description ("the cancel label", "a check
     icon"), unless it also restates the value: `` `errorFieldColor`
     (#d93025) `` is drift.
   - Display rules read as behaviour ("the system shall show X when Y").
   - A look-and-feel detail that can't be avoided is marked
     `<!-- UI concern -->`; marked content is a note, not a breach.
   - Open-questions sections hold design and architecture decisions, not UI
     questions.

3. **Cross-LLD ownership.** An LLD describes only its own subsystem's slice
   of a cross-cutting concern. Saying what another subsystem does or must
   do, restating its rationale or duplicating its rules is a breach even when
   accurate; a linked section reference (`see [Auth LLD §3.6]`) is the
   allowed form. An EARS `> Note:` likewise says only what this subsystem
   doesn't do, and links the other.

4. **Telemetry signals.** An LLD that documents log events carrying product
   intelligence has a `## Telemetry signals` table of rate pairs: the
   denominator (happy-path) event first, then each failure signal, naming its
   denominator in "Pairs with".

5. **Known failures.** Each error-handling row names a typed outcome (the
   raising side) or a user-visible presentation with its recovery actions
   (the presenting side), never just "throws" or "shows an error". A
   presented failure links the LLD that raises it instead of restating it.
   Where AGENTS.md lists the surfaces a known failure may show on, the row
   names one or says why none fits. Where the project has an app-wide error
   boundary, any other LLD's catch-all for unexpected exceptions records why,
   and logs at critical level with the project's unexpected-failure signal.

6. **Stable IDs** (spec IDs, open-question numbers) are never renumbered or
   reused.
