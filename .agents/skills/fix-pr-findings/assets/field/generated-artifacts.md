# Generated artifacts committed with their sources

## Fix

- A fix that touches a source of a generated output (the output paths AGENTS.md names) re-generates those outputs and stages them in the same commit as the source. Never edit a generated output by hand.
- If a gate reports generated files out of date, stage the regenerated outputs and run the gates again; commit only when they pass with outputs and sources staged together.
- A fix that touches no source must leave the generated outputs unchanged; if the gates regenerate something anyway, stop and report it rather than committing it: the outputs were stale before this fix.

## Report

- For each fix, the outputs it re-generated and committed with it.
