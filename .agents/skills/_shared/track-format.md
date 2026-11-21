# Track format

The one notation for tracks. `/managerial` writes them in the progress doc;
`/coding-master` reads them, and writes them itself when the owner describes
tracks in prose or types one with comments. A track copied from the progress
doc can be passed to `/coding-master` as it is.

## Notation

- `->` (or `→`) joins steps in order: the next step starts once everything in
  the previous step has merged.
- `[a, b]` is one step whose items run side by side; it is finished once all
  of them have merged. An item may be a chain: in `[15 -> 16, 13]`, #16
  follows #15 while #13 runs alongside.
- `,` outside brackets separates tracks, which run side by side.

Examples:

- `12 -> [15, 13] -> 5`: #12; once it merges, #15 and #13 together; once
  both have merged, #5.
- `12 -> 15, 13 -> 5`: two tracks: #12 then #15, and alongside them #13
  then #5.

## Markers

The progress doc, and the coordinator's status page, add markers to the same
notation:

```
Track A: ~~#12~~ -> 🔄#15 -> [#17 -> #18, #19] -> ⏸ Wait for #20 -> 👤#22
```

- `~~…~~`: done, struck through; the arrows aren't.
- 🔄 prefix: in progress. Dropped once the item is struck.
- `⏸ Wait for #N`: a step of its own that holds the track until #N
  merges; it doesn't start #N. Why it waits goes in the held ticket's table
  row, not in the track.
- 👤 prefix: the owner takes part beyond the final check every ticket gets:
  the owner's own task (a session may only track it), or a `curated` ticket,
  where the owner gives input before work starts.

## Reading a track

Skip struck-out items, ignore the 🔄 and 👤 markers (the mode comes from the
issue's label), and treat `⏸ Wait for #N` as a hold until #N merges.
