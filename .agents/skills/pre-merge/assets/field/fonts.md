# Fonts

## After rebase

Glyph manifests: when both sides added glyphs, keep both entries. If both
took the same code point, keep both entries for now; *Unique identifiers*
moves this branch's glyph.

## Unique identifiers

Code points are a registry of permanent public identifiers: apps that use
the font address glyphs by code point, so a change breaks them silently.
Check the branch against `origin/<base>` with the project's code point check
when AGENTS.md names one, otherwise by comparing each manifest's code
points on both sides (`git show origin/<base>:<manifest>`):

- **A code point on the default branch is missing.** Stop and report it:
  only the developer can accept the break.
- **A code point on the default branch now has a different glyph name.**
  Show the developer the glyph's source on `origin/<base>` and at `HEAD`,
  and ask: "U+<code point> was renamed from `<old>` to `<new>`. Is it still
  the same drawing? (yes / no)". Yes: continue and list the rename in the
  summary. No: stop; restore the old glyph at its code point and give the
  new one the next free code point, or have the developer accept the break.
- **A code point is used twice in one font.** The default branch took it
  first, so this branch moves: give its glyph the next free code point,
  never one on the default branch, regenerate, commit, and list the move in
  the summary and the PR description.

## Rebuild

Name every added or changed glyph with its code point in the commit body,
and put each moved code point in its own bullet.

## Follow-up issues

For a glyph, *Current state* shows its source excerpt or manifest entry
with the glyph's name and code point.

## Summary

```
Code points:          no clashes (<moved code points as old → new, or "none moved">; <renames confirmed as the same drawing, or "no renames">)
```
