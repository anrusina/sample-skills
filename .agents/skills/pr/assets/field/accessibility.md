# Accessibility

## Testing checklist

When the diff changes anything a user sees or operates:

- [ ] Keyboard only: every changed control is reachable and operable, focus is
  visible and moves in a sensible order, nothing traps focus
- [ ] Screen reader: changed content and controls are announced with the right
  name, role and state (name the reader and browser or platform used)

Automated accessibility checks the gates already run (axe, a lint plugin) do
not replace these two lines.
