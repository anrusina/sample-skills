# Fonts

## Gate results

A build warning about glyph geometry (ink outside the box the project's glyph
standards set, say) blocks like an error: show the full output and stop.
Default to fixing the glyph against the glyph standards AGENTS.md points to.
Never loosen the check, its tolerance or its strict flag.

## Commit message

- Name every added or changed glyph with its code point, e.g.
  ``- Add `needle-threader` (U+E04A) to the icon font``.
- A changed or removed code point on a released glyph breaks every app that
  uses it: call it out in its own bullet.
