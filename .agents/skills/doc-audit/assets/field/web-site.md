# Public web site

## Docs checks

- **Product claims.** For each changed user-facing string (locale files,
  content collections, page copy): every product fact matches AGENTS.md's
  product-facts section exactly, and every other product claim is stated in a
  source document AGENTS.md names (a brief, a facts registry). A claim with no
  source is **Broken**.
- A product fact changed in AGENTS.md while the strings that state it did not
  follow is **Stale**.
- A page's title and description, where a spec states them, match what the
  page sets.
