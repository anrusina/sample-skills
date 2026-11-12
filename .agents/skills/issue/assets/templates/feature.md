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
- <One EARS spec line per acceptance condition. Assign new spec IDs if they don't exist yet — create them in `docs/specs/EARS-<subsystem>.md` before closing this issue.>

## Upstream

- **HLD:** <section name> (`docs/specs/HLD.md`)
- **LLD:** `docs/specs/LLD-<subsystem>.md` — create if missing
- **Spec IDs:** <SUBSYSTEM-NNN, ...> — create in `docs/specs/EARS-<subsystem>.md` if missing
