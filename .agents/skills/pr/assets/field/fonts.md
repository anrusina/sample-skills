# Fonts

## What changed

**Glyphs:** when a font's sources or manifest changed, add a table of the
glyphs added, changed or removed, with name and code point. For a whole new
font, group them (by the manifest's grouping, with counts and code-point
ranges) instead of listing every glyph.

Run the code-point check AGENTS.md names against `origin/<base>`. If a glyph
that exists on `<base>` changed its code point or was removed, say so in bold
under the table: apps refer to glyphs by code point, so this breaks them.

## Testing checklist

- [ ] New or changed glyphs checked in the project's preview: at the sizes and
  polarities the glyph standards name, next to their neighbours, with the
  source overlay matching
