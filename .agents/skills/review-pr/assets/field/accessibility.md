# Accessibility

## Review checks

- Apply every rule in AGENTS.md's accessibility section, then every item of the accessibility checklist it names (a review checklist file, for example), and the accessibility standard and level it names where both are silent. AGENTS.md and the checklist are the lists: apply them, do not restate them here.
- Look beyond what the automated checks (an axe run, a jsx-a11y lint) can see: focus order and a visible focus indicator, keyboard operation of every control, names announced for icon-only controls, state changes announced, contrast in every theme the project has, motion that respects reduced-motion settings.
- Severity floors: any WCAG AA failure is at least **High**; a WCAG A failure that blocks a task (a control a keyboard or screen-reader user cannot reach or operate) is **Critical**.
- Every accessibility finding cites the WCAG success criterion it breaks (for example "2.4.7 Focus Visible") or the AGENTS.md rule or checklist item.
- A finding whose failure needs a real screen reader, a real device or a browser you could not run is **unsure**; say which one in its *Unverified* line.

## Verification

- A **Manual** row: what was checked by hand (keyboard only, a screen reader, zoom to 200%, the browsers), or "not run" with the reason. Automated accessibility checks belong in their gate's row.
