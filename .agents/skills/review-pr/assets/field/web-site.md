# Public web site

## Review checks

- Apply every rule in AGENTS.md's search, links and performance-budget sections.
- Indexing: a non-production build that loses its `noindex`, or a change that would publish a page or locale AGENTS.md keeps unpublished, is **Critical**.
- Search fields: each page has its own title and description (from the translation files where the project localises), one `h1`, no text only in images, nothing that needs JavaScript to be read. A wrong or missing field is **High**.
- Links: internal links go through the project's link helper (so they keep the locale); fragments match a real `id`; external links use `https`; a link that opens a new tab says so. Check each new external URL by hand (`curl -sI <url>`) and record the status.
- Claims about the product (names, domains, contact addresses, legal lines) match the facts AGENTS.md records exactly; a false claim is **Critical**.
- Privacy: no request to a third-party host (fonts, scripts, images, embeds) and no cookie beyond what AGENTS.md allows.
- Performance: a change that breaks the budget is fixed, not exempted; a performance risk under the budget is **Medium**.

## Inline comments

- Blast-radius examples: Cross-cutting — the page shell (header, footer, layout), a shared component, the link helper, theme tokens. Systemic — build settings, routing and locales, indexing and `robots.txt`, the hosting configuration.

## Verification

- Copy the per-page size or budget table the gate prints.
- A row for the external URLs checked with `curl -sI`, with their status codes.
