# Node (TypeScript, JavaScript, React, Astro)

## Doc comments

- TSDoc: `/** … */` blocks directly above the declaration. A `//` comment is
  not picked up by editors or doc tools.
- Parameters as `@param name - fragment`, results as `@returns fragment`;
  link identifiers with `{@link Name}`.
- In a component (React, Astro), document the props type, not each render
  detail: what a prop does when absent, and which props depend on each other.
- `// @spec AUTH-001` tags are plain `//` comments on the line before the
  `test(...)` or `it(...)` call.

```ts
// Bad — paraphrases the name
/** Returns the cart total. */
function cartTotal(cart: Cart): Money {}

// Good — explains the contract
/** Sum of line prices after discounts, before tax and shipping.
 *  Zero for an empty cart; never negative, since a discount is capped
 *  at its line's price. */
function cartTotal(cart: Cart): Money {}
```

## Docs checks

- Where AGENTS.md names a dependency record (a document with one row per
  direct dependency), every direct dependency in `package.json` has a row with
  the same version, and every row has a dependency. A missing or mismatched
  row is **Stale**.
