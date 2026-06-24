---
name: close-cli
description: "Signal that this CLI session is ending. Write anything worth persisting to memory, then stop. Trigger: user is about to close this CLI."
model: claude-haiku-4-5-20251001
---

This CLI session is closing. Before stopping:

1. Write anything worth persisting to memory (decisions made, feedback given, project state changes, anything non-obvious that would help future sessions).
2. Skip memory writes for things already in code, git history, or AGENTS.md — only save what isn't derivable from the repo.
3. Staleness check: for any memory **recalled during this session** that looked stale (contradicted by the repo, a renamed file/skill, a resolved condition, or an obviously outdated claim), verify it against the current repo and either fix it or remove it. Only act on memories that actually surfaced this session — do not audit the whole memory directory here.
4. Respond with a short summary, then stop. Nothing else — one sentence per memory file **written (created/updated) or removed** this session. Do not list recalled memories. If nothing was written or removed, respond with a single sentence saying so.
