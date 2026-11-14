# Fonts

## Triage

- Verify a glyph finding against the glyph standards AGENTS.md names (the per-font instructions and the reference drawings), not against the comment alone.
- A glyph's look is the developer's call: when a finding asks to change a glyph's shape away from its reference drawing, recommend, but say plainly that it changes the drawing.
- Never change a released glyph's code point to fix a finding. If that looks like the only fix, recommend Defer or Leave as-is and ask.

## Fix

- Before a glyph fix, read the glyph standards AGENTS.md names and the font's own instructions.
- Keep the glyph's code point and name; change only the source coordinates or manifest fields the finding names.
- If a gate reports a glyph check failure (ink box, stroke size), fix the glyph; never loosen the check.

## Report

- For each fixed glyph, a reminder to look at it in the project's preview, at the sizes the standards name and in both polarities, before merging.
