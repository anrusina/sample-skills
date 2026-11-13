# Python

## Doc comments

- Docstrings (PEP 257): a triple-double-quoted string as the first statement
  of the module, class or function. A `#` comment above a `def` is not a
  docstring.
- First line: one summary sentence. Then a blank line before any detail.
- Arguments, return values and raised exceptions in the section style the
  codebase already uses (Google `Args:` / `Returns:` / `Raises:`, or NumPy);
  never mix the two in one project.
- Identifiers in backticks (`` `order_total` ``).
- `# @spec AUTH-001` tags are plain `#` comments on the line before the test
  function, never inside its docstring.

```python
# Bad — paraphrases the name
def order_total(cart):
    """Return the order total."""

# Good — explains the contract
def order_total(cart):
    """Sum of `cart`'s line prices after discounts, in minor currency units.

    An empty cart returns `None`, not `0`, so callers can tell "nothing to
    pay for" from a fully discounted order.
    """
```
