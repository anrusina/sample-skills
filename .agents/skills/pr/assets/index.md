# pr assets

Load every asset whose condition holds at the start of the run (see the
skill's *Project facts*). Each step names the asset section it applies.
`testing-checklist.md` is the core template for the `## Testing:` section and
always applies.

| Kind | Id | Applies when (generic copy) | Provides here |
|---|---|---|---|
| stack | `node` | `package.json` at the repo root (covers TypeScript, React, Astro and other Node toolchains) | a *What changed* line naming where each new dependency's check is recorded |
| field | `accessibility` | AGENTS.md has accessibility rules (a section, or WCAG named) | keyboard-only and screen-reader manual check lines |
| field | `i18n` | the project ships more than one locale, or AGENTS.md has localisation rules (translation files, no hard-coded strings) | every-locale and second-locale check line |
| field | `frontend-ui` | the project has a user interface with a theme or design tokens, or AGENTS.md has layout or theming rules | widths and both-themes check lines |
| field | `web-site` | the project is a public web site with rules for search, links, product claims or a performance budget (a web *app* without them doesn't qualify) | browser check line |
| field | `generated-artifacts` | build outputs are committed alongside their sources (whatever AGENTS.md calls them) | outputs-committed and conditional-regeneration check lines |
| field | `fonts` | the project **builds** fonts from sources (glyph drawings, manifests, code points); bundling or using fonts does not qualify | glyph inventory table with breaking code-point changes in bold, visual preview check line |

Sections used: *What changed* (step 3), *Testing checklist* (step 6).
