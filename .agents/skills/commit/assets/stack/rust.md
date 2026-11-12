# Rust

## Scratch paths

Never staged: `target/`.

## Quality gates

- Format fix: `cargo fmt` (the checking form is `cargo fmt --check`).
- Suppression forms, never added on your own initiative: `#[allow(...)]`, `#![allow(...)]`, a lint lowered in `[lints]` or `clippy.toml`.

## Dependency registry

| Manifest | Publish date of `<x.y.z>` | Source repository |
|---|---|---|
| `Cargo.toml` | `curl -s -A "dependency-check" https://crates.io/api/v1/crates/<name>/<x.y.z> \| jq -r '.version.created_at'` | `curl -s -A "dependency-check" https://crates.io/api/v1/crates/<name> \| jq -r '.crate.repository'` |

crates.io refuses requests without a `User-Agent`, hence `-A`.

Record: a `# Checked <today>: …` comment directly above the dependency line in `Cargo.toml`.
