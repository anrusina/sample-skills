# Generated artifacts

## Fix comments

- Never edit a file under the output paths AGENTS.md names as generated: the
  next build overwrites it. Fix the comment in its source instead.
- When a fix touches a source that feeds a committed output, run the
  regenerate command from AGENTS.md's build section and leave the regenerated
  outputs beside the source change, so they reach the same commit. Say in the
  summary which outputs changed.
