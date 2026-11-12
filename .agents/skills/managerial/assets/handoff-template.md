# Handoff template

Fill every `<…>`. Save it as `phase-<N+1>-handoff.md` in the primary
checkout's git-ignored `docs/local-planning/`. Write each state as a fact you checked on GitHub
today, and keep the caveat at the top: the next manager verifies every line
before acting on it.

```markdown
# Phase <N+1> handoff — from the Phase <N> manager

> Written <date>. Check every state below on GitHub before acting. Things move daily.
> Questions: message the Phase <N> manager session (`local_<id>`) while it still runs; otherwise ask the owner.

## Where things stand

- <phase N's end state: what is done, what is still open and why>
- <in review: #N — what, PR #P>
- <Phase N+1's planning ticket, and whether its body is current>
- <proposed framing for Phase N+1, marked "not yet confirmed" where the owner hasn't agreed it>

## Owner principles that shaped Phase <N>

- <one line each: the principle, and the example that set it>

## Hard sequencing constraints

1. <tickets that must run one at a time, in one track, and why>

## Open questions

- <question> — waiting for <whom or what>

## Date-gated tickets

- #N — <what>, not before <date> (<reason, e.g. the 14-day rule>)

## Side work in flight

- <tracks outside the two app tracks, and tickets deliberately pushed later>

## Gotchas learned in Phase <N>

- <one line each>

## Reference

- Progress doc: <link, or path in `docs/local-planning/`>
- Memory: `project_phase<N>_plan.md`, plus per-ticket memories
```
