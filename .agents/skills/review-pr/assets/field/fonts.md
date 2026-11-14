# Fonts

## Review checks

- Read first: the glyph standards AGENTS.md names (the per-font instructions and the reference drawings). They override default review guidance. For a changed glyph, read its source drawing, its manifest entry and its neighbours in the same group; for a changed build function, its callers and every manifest it reads.
- Glyph standards: every rule the standards state (ink box, stroke and gap sizes, detail and precision limits, optical centring, shared geometry). A glyph outside the ink box or unreadable at the smallest size the standards name is at least **High**.
- Distinctiveness and legibility: a changed glyph must stay distinct from every other glyph in its font at the sizes the standards name. Two glyphs that read alike are **High**.
- Code points are permanent public identifiers: a released code point changed, removed or reused is **Critical**. Run the project's code-point check against `origin/<base>` where AGENTS.md names one. A rename keeps the same drawing.
- Font identity and metrics: a change to metrics, names or the content hash that the PR does not explain is **High**; a build whose output differs between two runs is **Critical**.
- A build check that can no longer fail (a tolerance widened, a strict flag dropped, an error caught and ignored) is **High**.
- Not findings: a deliberate departure from the reference drawing that the PR or the font's instructions explain; disagreement with a document AGENTS.md marks as non-normative (an investigation, a spike).
- A finding that depends on how a glyph renders, where no preview could be opened, is **unsure**.

## Inline comments

- For a glyph, the description names the size and polarity where the problem shows; the Suggestion gives the source coordinates or manifest field to change.
- Blast-radius examples: Isolated — one glyph, one manifest field, one doc line. Systemic — released code points, font metrics, the font's content hash.

## Verification

- A **Glyphs looked at** row: each changed glyph opened in the project's preview at the sizes the standards name, in both polarities and next to its neighbours, or "not run" with the reason.
- The code-point check's result, with any rename it reports.
