<One sentence — what is broken and in which context.>

## Read first

| Document | Why |
|---|---|
| `AGENTS.md` | Arrow of Intent, architecture and coding rules, build and test commands |
| <`docs/specs/LLD-<subsystem>.md`> | <what in it bears on this work> |

<One row per existing document (or section) that bears on this work, never
spec IDs. See /issue step 2.>

## Steps to reproduce
1. <Step>
2. <Step>
3. Observe: <what actually happens>

## Expected behaviour
<What the EARS spec says should happen.>

## Actual behaviour
<What is observed. Include error messages or stack traces.>

## Current code
// path/to/file — functionName
<snippet with ← annotation on the broken line>

## Scope in
- Fix the broken behaviour described above

## Scope out
- <Any related cleanup or refactor — open a separate feature issue>

## Done when
- Reproduction steps no longer produce the observed failure
- Regression test added, tagged `// @spec <SUBSYSTEM-NNN>`

## Upstream
- **Violates spec:** SUBSYSTEM-NNN — <spec text>
- **LLD:** `docs/specs/LLD-<subsystem>.md`
