# LLD format (`docs/specs/LLD-<subsystem>.md`)

One file per subsystem. Filename must match the subsystem name used in the HLD exactly.
Required sections in order:

### 1. Purpose
One sentence. What does this subsystem do?

### 2. Inputs / Outputs
Explicit types and sources/destinations. Must be consistent with HLD data flow.

### 3. Component design
Named internal components and their responsibilities. No code — describe the design in prose.

### 4. Data structures
Key types with field names and types. Field-level detail is appropriate here.

### 5. State machine (if applicable)
States, transitions, and triggers. Mermaid `stateDiagram-v2`.

### 6. Error handling
Failure modes and how they surface to the caller or user.

### 7. EARS spec IDs covered
List of spec IDs this LLD backs:
```
SUBSYSTEM-NNN: one-line summary
```

### 8. Open questions
Unresolved decisions that need answers before implementation begins.

**Does NOT belong in LLD:** actual code, details of other subsystems (reference them, don't describe them), look-and-feel specifics (exact colours, pixel sizes, font names, animation parameters — those belong in wireframes or the design system). Open-questions sections hold design/architecture decisions only, not UI/wireframe questions.
