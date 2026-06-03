# HLD format (`docs/design/HLD.md`)

One file for the whole system. Required sections in order:

### 1. Purpose
One paragraph. What does the system do and for whom?

### 2. Scope
| In scope (current phase) | Out of scope |
|---|---|

### 3. System context
External actors and boundaries — what touches the system from outside.
Mermaid `flowchart LR` diagram required.

### 4. Subsystems
One `###` heading per subsystem. Each must include:
- **Responsibility:** one sentence
- **Inputs:** what enters this subsystem and from where
- **Outputs:** what leaves and where it goes
- **Key constraints:** hard limits or non-obvious rules

### 5. Data model
High-level entities and relationships only. No field-level detail.
Mermaid `erDiagram` or entity list with relationship descriptions.

### 6. Data flow
How data moves between subsystems end-to-end.
Mermaid `flowchart LR` or `sequenceDiagram`.

### 7. Architectural decisions
| Decision | Choice | Rationale |
|---|---|---|

One row per meaningful decision. Include briefly why alternatives were rejected.

### 8. Non-functional requirements
Performance targets, offline behaviour, platform constraints.

**Does NOT belong in HLD:** algorithms, class/function names, UI layout, field-level data model, EARS specs.
