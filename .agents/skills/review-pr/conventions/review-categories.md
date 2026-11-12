# Language and framework review checks

`/review-pr` step 6 loads this file and applies every check below to the
changed code. These defaults are language-agnostic: they name failure
classes that recur in any stack. A project tailors the review to its stack by
replacing or extending this file — the framework's lifecycle hooks, its
rendering model, its concurrency primitives, the idioms its own reviewers
keep flagging. Keep each check concrete enough that a reviewer can point at a
line that breaks it.

The project rules in `AGENTS.md` (layer rules, logging, error handling,
design tokens) are checked by `/review-pr` itself, not here. Put a check here only
when it follows from the language or framework rather than from a project
decision.

## Resource lifecycle

- A subscription, listener, observer, timer, stream, animation or other
  long-lived handle acquired by a component or service and never released in
  its teardown (dispose, unmount, close, deinit, finalizer)
- A file, socket, database connection or transaction opened on a path that
  can exit early (return, throw) without closing it — no `finally`, no
  scoped/`using`/`with`/`defer` construct
- A callback that fires after its owner was torn down and then touches the
  owner's state (updating a disposed view, writing to a closed store)

## Rendering and UI frameworks

Skip this section when the change has no UI code.

- Expensive work on the render path: I/O, parsing, sorting or other
  non-trivial computation inside a render/build function, or allocation that
  happens on every frame or every re-render
- Re-renders broader than the change needs: state held too high in the tree,
  a whole view subscribed to a store when it reads one field, a memoisation
  or constant-construction opportunity the framework offers and the code
  forgoes
- Work started in a render function rather than in the lifecycle hook or
  state layer the framework provides for it, so it repeats on every render

## Concurrency and async

- Shared mutable state touched from more than one task, thread or isolate
  without the synchronisation the language provides
- A check-then-act sequence across an `await` (or other suspension point)
  whose condition can change before the act runs — a reload, a cancelled
  operation, a second caller
- An operation that can be started twice concurrently (double submit,
  re-entrant load) with no guard, cancellation or de-duplication
- Results of a superseded request applied after a newer one (last-writer
  ordering not enforced)

## Types and absent values

- An escape from the type system — an unchecked cast, a dynamic/any-typed
  value, a non-null assertion — on a value that can in fact be the other type
  or absent at that point
- An absent, empty or default value treated as a valid one (an empty string
  as an ID, zero as "not set") where the domain distinguishes them
- Equality or hashing that disagrees with the type's identity (mutable fields
  in a hash key, reference equality where value equality is meant)

## Data and persistence

- A multi-step write that is not atomic where a failure between steps leaves
  the stored data inconsistent
- A schema or stored-format change with no migration for data already
  written by an earlier version
- Serialisation that silently drops or defaults a field it does not
  recognise, losing data on a round trip

## Language idioms

- Use of an API the language or framework marks deprecated, where its
  replacement is available in the version the project pins
- Re-implementing what the standard library or an existing project utility
  already provides, when the hand-written version handles fewer edge cases
