# fix-pr-findings assets

Load every asset whose condition holds at the start of the run. Each file has
H2 sections named after the step that applies them:

- *Triage* — step 3: what to weigh before recommending Fix, Defer or Leave as-is
- *Fix* — step 6: pasted into each sub-agent's prompt as its field and stack rules
- *Report* — step 8: what the final report adds

An asset without a section adds nothing at that step. This skill has no stack
assets: the gates and the wrapper come from the project facts.

| Kind | Id | Applies when (generic copy) | Provides here |
|---|---|---|---|
| field | `generated-artifacts` | build outputs are committed alongside their sources (whatever AGENTS.md calls them) | a fix that touches a source re-generates and re-stages its outputs |
| field | `fonts` | the project **builds** fonts from sources (glyph drawings, manifests, code points); bundling or using fonts does not qualify | code points never change to fix a finding, a glyph's look is the developer's call, a preview reminder |
