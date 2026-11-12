# Python

## Doc comments

- Docstrings (PEP 257): a triple-double-quoted string as the first statement
  of the module, class or function. A `#` comment above a `def` is not a
  docstring.
- First line: one summary sentence. Then a blank line before any detail.
- Arguments, return values and raised exceptions in the section style the
  codebase already uses (Google `Args:` / `Returns:` / `Raises:`, or NumPy);
  never mix the two in one project.
- Identifiers in backticks (`` `build_font` ``).
- `# @spec AUTH-001` tags are plain `#` comments on the line before the test
  function, never inside its docstring.

```python
# Bad — paraphrases the name
def ink_box(glyph):
    """Return the ink box."""

# Good — explains the contract
def ink_box(glyph):
    """Smallest box holding every drawn point of `glyph`, in font units.

    Empty glyphs return `None`, not a zero box, so callers can tell a
    blank glyph from one drawn at the origin.
    """
```
