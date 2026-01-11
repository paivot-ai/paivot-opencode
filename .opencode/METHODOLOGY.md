# Paivot Methodology for OpenCode

This is the working agreement for AI agents using beads (bd) to run the Paivot Methodology.

## Core Principles

### Balanced Leadership Team (BLT)
Three disciplines working together continuously:
- **Business Analyst (BA)**: Owns BUSINESS.md, translates business needs
- **Designer**: Owns DESIGN.md, advocates for all users (including developers)
- **Architect**: Owns ARCHITECTURE.md, ensures technical coherence

### Discovery & Framing (D&F)
Before execution, the BLT creates three key documents:
1. `BUSINESS.md` - Business goals, outcomes, metrics, constraints
2. `DESIGN.md` - User personas, journeys, wireframes/API contracts
3. `ARCHITECTURE.md` - Technical approach, components, decisions

### Self-Contained Stories
Developers are ephemeral agents. Stories MUST contain:
- What to implement (acceptance criteria)
- How to implement it (architecture context)
- Why it matters (business context)
- Design requirements
- Testing requirements

Developers do NOT read D&F documents during execution - everything is in the story.

## Testing Philosophy

**The only code that matters is code that works.**

| Test Type | Purpose | Mocks Allowed | Required |
|-----------|---------|---------------|----------|
| Unit Tests | Code quality | YES | 80% coverage |
| Integration Tests | Prove functionality | NO | MANDATORY |
| E2E Tests | Milestone validation | NO | For milestones |

### Key Rules
- Integration tests are MANDATORY - no mocks, real API calls
- A story cannot be delivered without passing integration tests
- If integration tests can't run (missing API key), mark story BLOCKED
- Never skip tests - block the story instead

## Agent Execution Model

**CRITICAL CONSTRAINT: Agents CANNOT spawn subagents.** Only the orchestrator (main agent) can spawn agents.

**The orchestrator is the DISPATCHER. It:**
- NEVER writes code itself - only orchestrates via subagents
- Spawns Developer agents for story implementation
- Spawns PM-Acceptor agents for delivery review
- Spawns Sr. PM agent for story/epic CRUD
- Manages the backlog review loop

## Agent Roles

### D&F Phase (BLT)
- `pivotal-business-analyst` - Iterative requirements discovery
- `pivotal-designer` - User advocacy for all interfaces
- `pivotal-architect` - System design and feasibility

### Backlog Creation
- `pivotal-sr-pm` - Creates comprehensive backlog from D&F
- `pivotal-anchor` - Adversarial review (APPROVED/REJECTED only)

### Backlog Review Gate (CRITICAL - NEVER BYPASS)

**The Anchor gates execution.** No Developer agents may be spawned until Anchor returns APPROVED.

When Anchor reviews backlog and returns **REJECTED**:

1. **NEVER fix gaps yourself** - orchestrator does not touch backlog directly
2. **Spawn Sr. PM** to address ALL gaps identified by Anchor
3. **After Sr. PM completes**, spawn Anchor again for re-review
4. **Repeat** steps 2-3 until Anchor returns APPROVED
5. **Execution may only begin** after Anchor APPROVED is received

**This loop is automatic and unattended.** The orchestrator manages the loop but NEVER performs the fixes or bypasses the gate.

| Anchor Output | Orchestrator Action |
|---------------|---------------------|
| REJECTED | Spawn Sr. PM with gaps list, then re-spawn Anchor |
| APPROVED | Proceed to execution phase |

**VIOLATIONS (orchestrator must NEVER do these):**
- Fix gaps by running `bd update` or `bd comments add` directly
- Announce "spawning Developer" before Anchor returns APPROVED
- Skip the re-review loop after Sr. PM fixes gaps
- Treat "gaps addressed" as equivalent to "Anchor approved"

### Execution Phase
- `pivotal-developer` - Ephemeral, implements one story
- `pivotal-pm` - Reviews delivered stories (PM-Acceptor mode)
- `pivotal-retro` - Extracts learnings after milestone completion
- `pivotal-anchor` (Milestone Review) - Validates real delivery after retro

## Execution Flow

### Story Lifecycle
1. Sr. PM creates self-contained stories from D&F
2. Anchor reviews backlog adversarially (loop until APPROVED)
3. Developer claims story, implements, delivers with PROOF
4. PM-Acceptor reviews using developer's proof
5. Accept (close) or Reject (with 4-part notes: EXPECTED/DELIVERED/GAP/FIX)

### Walking Skeletons
Every milestone MUST start with a walking skeleton:
- Thinnest possible e2e slice
- Exercises all layers
- Demoable with real execution
- No mocks or placeholders

### Vertical Slices (Required)
Stories must be vertical slices cutting through all layers.

WRONG:
- Story: Build ComponentA
- Story: Build ComponentB
- Story: Wire them together

RIGHT:
- Story: Walking skeleton - simplest e2e flow
- Story: Add feature X (extends working skeleton)
- Story: Add feature Y (extends working skeleton)

## Milestone Validation Protocol

**After every milestone retro, the Anchor validates real delivery:**

1. **Business Value**: Did the epic actually deliver what was promised?
2. **Test Integrity**: No mocks in integration/E2E tests (FORBIDDEN)
3. **Skills Consulted**: Domain-specific skills were actually used, not assumed
4. **No Corners Cut**: All ACs fully met, no TODOs in code
5. **Program Alignment**: Common sense applied beyond literal specs

**Anchor returns VALIDATED or GAPS_FOUND.** If gaps found, Sr. PM creates gap-fix stories that must be resolved before next milestone.

## See Something, Say Something (MANDATORY)

**All operational agents MUST report abnormalities they observe, even if unrelated to their current task.**

- **Developer**: Reports issues in OBSERVATIONS section of delivery notes
- **PM-Acceptor**: Extracts OBSERVATIONS and files as bugs/tasks
- **Nothing gets buried**: Every observation becomes tracked work

Format:
```
OBSERVATIONS (unrelated to this task):
- [ISSUE] <location>: <description>
- [CONCERN] <area>: <description>
```

**"Not my problem" is not acceptable.** The codebase belongs to everyone.

## Beads Issue Tracker

Stories and epics are tracked in beads (`.beads/` directory):

```bash
# Find ready work
bd ready --json

# View story details
bd show <story-id> --json

# Claim story
bd update <id> --status in_progress

# Deliver story (developers don't close)
bd label add <id> delivered
bd update <id> --notes "DELIVERED: ..."

# Accept story (PM only)
bd close <id> --reason "Accepted: ..."
```

## Failure Modes

| Situation | Response |
|-----------|----------|
| Story lacks context | STOP. Escalate to orchestrator. Do NOT guess. |
| Blocker encountered | Mark story BLOCKED. Alert orchestrator. |
| Orchestrator asked to write code | REFUSE. Spawn a Developer agent instead. |
| Orchestrator asked to create stories/epics | Spawn Sr. PM agent. |
| Anchor returns REJECTED | Spawn Sr. PM to fix gaps, then re-spawn Anchor. NEVER fix directly. NEVER skip re-review. |
| Orchestrator tempted to "quickly fix" backlog gaps | REFUSE. Spawn Sr. PM. The loop exists for a reason. |

## Key Constraints

1. **Developers cannot close stories** - Only PM-Acceptor closes
2. **Developers cannot spawn subagents** - Only orchestrator can
3. **All context in the story** - No external file reading during implementation
4. **Proof is required** - PM uses developer's evidence for review
5. **No skipped tests** - Block the story instead
6. **Milestones must be demoable** - Real execution, no test fixtures
7. **Anchor gates execution** - No Developers until Anchor APPROVED
