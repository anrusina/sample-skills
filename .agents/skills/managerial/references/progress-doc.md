# The progress doc

Load this when creating the phase's progress doc or changing anything in it.

One doc per phase. Where a first-party docs connector is attached (the host
says so), make it a Claude Docs document: create it with the Artifact tool's
`quickstart`, intent `document`, and follow the type's instructions. Without
one, keep it as a Markdown file, `phase-<N>-progress.md`, beside the handoffs
in the primary checkout's git-ignored `docs/local-planning/`, and resend it
to the owner (`SendUserFile`, `display: "render"`) after every change. Copy
the previous phase's structure; its link or path is in the handoff or the
previous phase's memory file. Record the new doc's link or path and the ids
you need (doc, body node, status enum) in the phase's memory file.

## Structure

- **Intro line:** "As of <date>, <done> of its <total> items are done", plus
  anything that changed the phase's shape (e.g. "Phase 1 is complete").
- **Overview table:** one row per stage: stage, goal, items, done.
- **One table per stage,** with columns Ticket / What / Track / Status:
  - Ticket: the ticket link with its mode beside it: `#12 auto`,
    `#15 curated`, or `#18 you` for the owner's own task.
  - What: a short description.
  - Track: A or B, which ties the row to the track paragraphs.
  - Status: a chip from the doc's status enum: Not started / In progress /
    In review / Waiting / Done. (In a Markdown doc, the same five words as
    plain text.)
- **Outside table:** ticket link, what it is, and where or when it runs (e.g.
  "Phase 3; after #20 merges"). Done items are struck through, with
  "Done (PR #N merged <date>)".
- **Track A and Track B paragraphs,** in the track format (SKILL.md § *track
  format*).

## Keeping it current

**Sync every status change you verify** in all the places it shows:

- the ticket's chip;
- its stage's done count in the overview;
- the total in the intro, and the intro's date;
- 🔄 and strikethrough in the tracks;
- its Outside table row, if it has one.

A missed place is how the doc drifts; check all five every time.

**Sync every placement** the same way: adding or removing a ticket changes its
stage table, that stage's items in the overview, the intro's total, and the
track step it joins or leaves.

**Read before every edit.** People edit the doc between turns, the owner
included (they often set chips themselves). Keep a bookmark of the last
revision you read or wrote, and start each editing turn by reading what
changed since it. Never write your text over theirs. If a guard refuses an
edit, re-read and redo it from what stands now. (For a Markdown doc, re-read
the file at the start of every editing turn.)

## Connector mechanics

For a Claude Docs document only. The connector's guide (`topic.editing`) has
the general mechanics. What this doc needs on top:

- **Reads go through `read`,** never `update` (which refuses them):
  `{"kind":"view","sinceRev":N}` for what changed,
  `{"kind":"view","parentId":"<row id>"}` for one row, and
  `{"kind":"search","pattern":"#(12|15)\\b"}` for a ticket's rows and
  track mentions in one call.
- **Chips can't be found by text search:** a chip is a dropdown node, so
  searching "In progress" finds nothing. Search the ticket number for its row
  id, then view that row with `parentId`; the last cell's paragraph id and
  `h` are what the guarded `replace` names. Replace that paragraph as
  markdown with a dropdown block for the status enum. Record the enum's id
  and its option order in the memory file (e.g. 0 Not started, 1 In
  progress, 2 In review, 3 Waiting, 4 Done).
- **Words in a block:** a `replace` whose target is
  `{"kind":"find","text":"…","parentId":"<block id>"}`, with
  `"with":{"as":"text",…}`.
- **Track paragraphs:** for one step, find and replace as above. When
  several steps change, rewrite the whole paragraph with a guarded `replace`,
  `"as":"markdown"`: links and strikes survive, and the `dropped` notices it
  returns are harmless.
