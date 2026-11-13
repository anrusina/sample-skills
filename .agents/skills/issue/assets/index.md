# issue assets

`templates/<type>.md` holds the body template for each issue type; step 5
loads the one for the resolved type. The field assets below add to it. Load
every one whose condition holds; the step that uses a section names it.

| Kind | Id | Applies when (generic copy) | Provides here |
|---|---|---|---|
| field | [`accessibility`](field/accessibility.md) | AGENTS.md has accessibility rules (a section, or WCAG named) | *Done when* keyboard and standard lines; *Upstream* criterion for bugs; *Labels* |
| field | [`i18n`](field/i18n.md) | the project ships more than one locale, or AGENTS.md has localisation rules (translation files, no hard-coded strings) | *Done when* line for user-visible copy |
| field | [`frontend-ui`](field/frontend-ui.md) | the project has a user interface with a theme or design tokens, or AGENTS.md has layout or theming rules | *Done when* lines for widths, themes and reflow |
| field | [`fonts`](field/fonts.md) | the project **builds** fonts from sources (glyph drawings, manifests, code points); bundling or using fonts does not qualify | *Done when* line naming code points; *Current code* for glyphs |
