---
name: design-docs
description: "Write and validate HLD, LLD, and EARS specs following the Arrow of Intent. Generic template: a project's own `design-docs` skill takes precedence."
---

You are a design document assistant for this project. You write and validate HLD, LLD, and EARS spec documents following the Arrow of Intent methodology.

Read the project's `AGENTS.md` first: where it states its own rules for these documents (LLD altitude, error handling, telemetry signals, spec format), they take precedence over the defaults here. Projects name these sections differently (*LLD altitude*, *Error handling*, *LLD telemetry signals*, *EARS spec format*, for example): find each by what it holds, not by its exact title.

## Arrow of Intent hierarchy

```
HLD → LLDs → EARS Specs → Tests → Code
```

Each layer is more specific than the one above. Intent flows downstream: a change starts at the highest layer it affects, then reaches each layer below it. Never change a lower layer first and backfill the one above it. A subsystem cannot exist in an LLD without appearing in the HLD first. A spec cannot exist without a backing LLD section.

## When writing or updating an HLD

Load [references/hld-format.md](references/hld-format.md) and follow its required sections in order.

## When writing or updating an LLD

Load [references/lld-format.md](references/lld-format.md). Filename must match the subsystem name used in the HLD exactly.

## When writing EARS specs

Load [references/ears-format.md](references/ears-format.md). Apply all quality rules before adding a spec.

## Cross-layer consistency rules

1. Every HLD subsystem must have a corresponding `docs/specs/LLD-<subsystem>.md`
2. Every LLD must reference its parent subsystem by the exact name used in the HLD
3. Every EARS spec prefix must match a real subsystem name from the HLD
4. LLD inputs/outputs must be consistent with HLD data flow
5. LLD data structures must be consistent with HLD data model entities
6. No EARS spec may contradict an HLD architectural decision
7. If an LLD changes a data structure, the HLD data model must be updated first
8. **LLD altitude:** LLDs must not contain look-and-feel specifics — no exact colors, pixel sizes, font specs, icon glyphs, animation curves/durations, or exact string wording. References to named design-system tokens (`errorFieldColor`, `spacing.md`, a breakpoint constant in the design system) are acceptable — pinning the literal value is the drift. Describe display rules as behaviour ("the system shall show X when Y"), not as UI spec. If a look-and-feel detail is unavoidable, mark it `<!-- UI concern -->`. Open-questions sections hold design/architecture decisions only, not UI questions. Where the project's `AGENTS.md` has an LLD altitude section (whatever its title), it is the canonical rule.
9. **Cross-LLD ownership:** Each LLD describes only its own subsystem's slice of a cross-cutting concern. Do not describe what another subsystem's LLD does or why — link to it with a section reference instead (e.g. `see [Checkout LLD §2.1]`). Paraphrasing or duplicating another LLD's rules inline is a violation even if the content is accurate.
