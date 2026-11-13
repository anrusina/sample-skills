<One sentence — what this adds and why.>

## Read first

| Document | Why |
|---|---|
| `AGENTS.md` | Arrow of Intent, architecture and coding rules, build and test commands |
| <`docs/specs/LLD-<subsystem>.md`> | <what in it bears on this work> |

<One row per document that genuinely bears on this work. Name the document,
not spec IDs — the whole document, or at least the whole section, is the unit
to read. Only documents that already exist. See /issue step 2.>

## Goal

<What user-facing or system capability this delivers. Name the HLD subsystem it belongs to.>

## Scope in

- <What is included in this issue>

## Scope out

- <What is explicitly not included — name follow-up issues if known>

## Done when

- SUBSYSTEM-NNN: When [condition], the system shall [action].
- <One EARS spec line per acceptance condition. A spec that doesn't exist yet gets a provisional ID (the next free one), marked *provisional*; it is written into `docs/specs/EARS-<subsystem>.md` when the work starts.>

## Upstream

- **HLD:** <section name> (`docs/specs/HLD.md`)
- **LLD:** `docs/specs/LLD-<subsystem>.md`, or "to be written" when missing
- **Spec IDs:** <SUBSYSTEM-NNN, ...>, provisional ones marked as such
