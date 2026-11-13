# LLD format (`docs/specs/LLD-<subsystem>.md`)

One file per subsystem. Filename must match the subsystem name used in the HLD exactly.
Required sections in order:

### 1. Purpose

One sentence. What does this subsystem do?

### 2. Inputs / Outputs

Explicit types and sources/destinations. Must be consistent with HLD data flow.

### 3. Component design

Named internal components and their responsibilities. No code — describe the design in prose.

### 4. Data structures

Key types with field names and types. Field-level detail is appropriate here.

### 5. State machine (if applicable)

States, transitions, and triggers. Mermaid `stateDiagram-v2`.

### 6. Error handling

Failure modes and how they surface to the caller or user. This table is the subsystem's inventory of **known failures**, the ones it can anticipate. Unexpected failures (defects) are not listed here: where the project has an app-wide error boundary, it is their only home.

Each known failure is split between two LLDs, and each states only its own side:

- **Raising LLD:** the typed outcome (a named exception or result variant) and when it occurs. Never "throws an error".
- **Presenting LLD:** what the user sees and which recovery actions they have. It links to the raising LLD rather than restating it.

Where the project's `AGENTS.md` lists the existing surfaces a known failure may show on (for example an inline banner, a notice, a modal, or the screen's own failure view), the presenting LLD names which one shows the failure. A new surface is designed only when none of these fits, and the LLD states why. Where `AGENTS.md` names a component catalog, the presenting LLD's failure states also go in the list of states the catalog must show.

### 7. EARS file and namespace

Link to the corresponding EARS file and name the subsystem's general namespace(s), such as `AUTH-NNN`. This is a navigation aid, not a mapping from design sections to individual requirements. Do not cite numbered EARS IDs, EARS section anchors, or maintain a per-ID inventory in the LLD.

### 8. Open questions

Unresolved decisions that need answers before implementation begins.

### 9. Telemetry signals (required when logging is present)

Rate-pair table — denominator event first, then failure signals grouped under it:

| Signal | Level | Emitted when | Product intelligence | Pairs with |
|---|---|---|---|---|
| `event_name` | `info` | condition that triggers this event | what product decision this enables | — |
| `failure_name` | `warning` | failure condition | rate against denominator | `event_name` |

Rules: denominator event confirms happy path (no separate success signal needed); omit pure-noise logging; every failure signal names its denominator in "Pairs with".

**Does NOT belong in LLD:** actual code, details of other subsystems (reference them, don't describe them), or mappings to individual numbered EARS requirements. EARS-file links and general namespace labels are allowed for navigation; the LLD remains the source from which those requirements are derived.
