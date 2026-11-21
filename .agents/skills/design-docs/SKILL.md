---
name: design-docs
description: "Write or update the design documents along the Arrow of Intent: the HLD, one LLD per subsystem and its EARS specs, in the project's formats and altitude rules (behaviour, contracts and data, never look-and-feel). Use when intent must be written before code: a new subsystem, an LLD section, EARS requirements, or a gap /start-task reported (no HLD section, LLD or spec). Not for checking that the docs agree (/arrow-check) or auditing them against the code (/doc-audit). Generic copy: if a project skill named `design-docs` is also listed, use that one instead."
---

You write and validate HLD, LLD, and EARS spec documents following the Arrow of Intent.

Read the project's `AGENTS.md` first: where it states its own rules for these documents (LLD altitude, error handling, telemetry signals, spec format), they take precedence over the defaults here. Find each section by what it holds, not its exact title.

## Arrow of Intent hierarchy

```
HLD → LLDs → EARS Specs → Tests → Code
```

A change starts at the highest layer it affects, then reaches each layer below it; never change a lower layer first and backfill the one above. A subsystem cannot exist in an LLD without appearing in the HLD first, and a spec cannot exist without a backing LLD section.

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
8. Every design doc keeps the [design-doc rules](../_shared/design-doc-rules.md): no EARS IDs upstream, LLD altitude, cross-LLD ownership, telemetry signals, known failures, stable IDs.
