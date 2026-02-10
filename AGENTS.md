# Paivot - Modified Pivotal Methodology for AI Agents

This is the working agreement for AI agents using beads (bd) to run the Paivot Methodology. Optimized for ephemeral, short-context agent execution with testing requirements driven by story content.

## Core Principles

- **Outcomes first** - technical details support outcomes
- **Discovery & Framing before building** - explicit, structured discovery
- **Quality enables speed** - rigorous engineering and short feedback loops
- **Strict role boundaries** - agents do NOT step outside their roles
- **Testing is mandatory** - reasonable unit coverage + mandatory integration tests (no mocks, real API calls)
- **Trunk-based development** - ALL code commits go to `beads-sync` (NO feature branches per story)

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work (PM only)
bd sync               # Sync with git
```

> **Note**: In Paivot, only PMs close stories. Developers mark stories as `delivered` instead.

## Overview

- **Beads is crucial** - All state, context, decisions, and rejection history are tracked in beads
- The backlog is the single source of truth owned by the PM
- **Stories are self-contained execution units** - Sr. PM/PM embeds all context into stories
- **Default testing standard**: Reasonable unit coverage + **mandatory integration tests** (no mocks, real API calls)
- **No skipped tests** - if a test has a blocker, the story is blocked and user alerted
- Stories must be INVEST (Independent, Negotiable, Valuable, Estimable, Small, Testable)

## Git Workflow: Trunk-Based Development (MANDATORY)

**Paivot uses trunk-based development via beads-sync. NO feature branches per story.**

**Why:** Beads' hash-based IDs (`bd-a1b2`) eliminate merge collisions when multiple agents work concurrently on the same branch. The intelligent 3-way merge driver resolves field-level conflicts automatically. Feature branching defeats this design.

**Branch Structure:**
- `main` - Protected branch (requires PR for merges)
- `beads-sync` - Auto-managed sync branch where ALL agents commit concurrently
- Branches only for experiments (> 1 week, may discard) - requires `BEADS_NO_DAEMON=1`

**Developer Instructions:**
- ALL code commits go to `beads-sync` (NOT epic branches, NOT feature branches)
- Daemon auto-syncs beads state every 30 seconds
- Hash-based IDs prevent collisions when multiple agents work simultaneously
- `bd sync` forces immediate sync before critical operations

See `docs/GIT_WORKFLOW.md` for comprehensive trunk-based development guide.

## Agent Execution Model

**CRITICAL CONSTRAINT: Agents CANNOT spawn subagents.** Only the orchestrator (main agent) can spawn agents.

**The orchestrator (main agent) is the DISPATCHER. It:**
- NEVER writes code itself - only orchestrates via subagents
- Spawns Developer agents for story implementation
- Spawns PM-Acceptor agents for delivery review
- Spawns Sr. PM agent for story/epic CRUD
- Manages parallelization and agent budget directly

**FSM HARD ENFORCEMENT (when piv is initialized):**

The PreToolUse hook enforces the FSM at the tool level:
- Calls `piv next` before every agent spawn
- **Blocks any action that doesn't match** FSM recommendation
- **Blocks wrong story** - must work on FSM-prioritized story
- **Blocks excess spawns** - respects parallelization limits

The orchestrator CANNOT bypass the FSM - the hook will reject mismatched actions.

### Agent Spawning Rules

| Role | How to Invoke | Lifespan | Scope |
|------|---------------|----------|-------|
| Sr. PM | `@pivotal-sr-pm "Create/update stories for..."` | Ephemeral | Story/Epic CRUD |
| PM | `@pivotal-pm "File bug for..."` | Ephemeral | Bug filing |
| PM-Acceptor | `@pivotal-pm "Review delivered story <id>..."` | Ephemeral | One story |
| Developer | `@pivotal-developer "Implement story <id>..."` | Ephemeral | One story |
| Retro (Epic) | `@pivotal-retro "Run retrospective for epic <id>..."` | Ephemeral | One milestone epic |
| Anchor (Milestone) | `@pivotal-anchor "MILESTONE REVIEW for completed epic <id>..."` | Ephemeral | One milestone epic |
| Anchor (Backlog) | `@pivotal-anchor "Review backlog for gaps..."` | Ephemeral | Full backlog |

**The orchestrator (main agent) MUST:**
- Spawn these as subagents using the `@agent-name` syntax
- NEVER "become" or "act as" these roles itself
- NEVER write code itself - always spawn a Developer agent
- Spawn Sr. PM for story/epic CRUD (create/update/delete epics or stories)
- Spawn PM for bug filing (cheaper than Sr. PM)

## Testing Philosophy

| Test Type | Purpose | Mocks OK? | Required For |
|-----------|---------|-----------|--------------|
| **Unit** | Code quality | YES | 80% coverage |
| **Integration** | Real functionality | **NO** | Story completion |
| **E2E** | Full system works | **NO** | Milestones |

**Key principles:**
- **Mocks ONLY in unit tests** - unit tests prove code quality, not functionality
- **Integration tests are what matter** - real API calls, real DBs, no mocks
- **E2E tests gate milestones** - must be demoable with real requests hitting real code
- **Test scope: NARROW by default** - Run only tests affected by the story

**NEVER soften or simplify tests** to work around external issues. If an external dependency has problems, BLOCK the story.

## Discovery & Framing

D&F is an **outcomes-driven** process. All D&F documents live in `docs/`:
- `docs/BUSINESS.md` - Business outcomes, goals, constraints
- `docs/DESIGN.md` - User needs, UX/DX, wireframes
- `docs/ARCHITECTURE.md` - Technical approach, system design

**The Process**:
1. **Facilitator** engages user, extracts outcomes, goals, constraints
2. **BA** (via subagent) captures business outcomes → BUSINESS.md
3. **Designer** (via subagent) captures user needs, DX → DESIGN.md
4. **Architect** (via subagent) captures technical approach → ARCHITECTURE.md
5. **Adversarial Backlog Creation**:
   - **Sr PM** creates backlog with walking skeletons, vertical slices, embedded context
   - **Anchor** reviews looking for gaps
   - If REJECTED: **Sr PM fixes gaps**, then **Anchor re-reviews** (orchestrator manages loop)
   - **Loop continues** until Anchor returns APPROVED
6. **Green light for execution** - ONLY after Anchor explicitly returns APPROVED

## Execution Loop Priority Order

1. **PM-Acceptor for delivered stories** - Review delivered work first
2. **Developer for rejected stories** - Fix rejected work before new work
3. **Developer for ready stories** - Implement new stories

## Delivery Workflow (CRITICAL)

```
Developer: bd label add <id> delivered
Developer: bd update <id> --notes "DELIVERED: [PROOF SECTION]"
(Story stays in_progress with delivered label - developer does NOT close)

PM-Acceptor reviews (evidence-based):
  - Uses developer's proof instead of re-running tests
  - Accept: bd label remove <id> delivered && bd label add <id> accepted && bd close <id>
  - Reject: bd label remove <id> delivered && bd label add <id> rejected && bd update <id> --status open --notes "REJECTED [YYYY-MM-DD]: ..."
```

**Developer's PROOF section MUST include:**
```
DELIVERED:
- CI Results: lint PASS, test PASS (XX tests), integration PASS (XX tests), build PASS
- Coverage: XX%
- Commit: <sha> pushed to origin/beads-sync
- Test Output: [paste relevant test output or summary]

LEARNINGS: [optional - gotchas, patterns discovered]
```

## Strict Role Boundaries

**Each agent ONLY does its job. Agents do NOT step outside their roles.**

| Agent | Does | Does NOT |
|-------|------|----------|
| Orchestrator | Spawn agents, manage execution loop, dispatch stories | Write code, manage backlog directly |
| Sr. PM | Create/update/delete stories and epics, embed context | Write code, implement stories |
| PM-Acceptor | Review deliveries, accept/reject stories, close accepted, file bugs | Write code, create stories/epics |
| Developer | Implement assigned story, write tests, record proof, deliver | Close stories, modify backlog, modify other repos (read/file bugs only) |

## Learnings Lifecycle

1. **Developers** record `LEARNINGS:` in delivery notes
2. **PM-Acceptor** captures test gap learnings when bugs slip through
3. **Retro agent** harvests learnings after milestone epics complete, writes insights to `.learnings/`
4. **FSM HARD GATE**: After retro, enters `LEARNINGS_REVIEW` - execution blocked until Sr. PM reads `.learnings/` and updates open stories
5. **Future work benefits** from accumulated knowledge embedded in story context

## Milestone Validation Protocol (MANDATORY)

After EVERY milestone epic retro, the Anchor MUST validate the completed work:

**Purpose:** Validate reality, not just process compliance:
- Did the epic deliver its business value?
- Do the tests prove real functionality (not mocked)?
- Were skills actually consulted (not assumed)?
- Were corners cut?

**Anchor validates:**
- [ ] Business value delivery (users can do what was promised)
- [ ] Test integrity (NO mocks in integration/E2E tests)
- [ ] Skills consultation (domain-specific work consulted relevant skills)
- [ ] No corners cut (every AC fully met, no TODOs, no disabled tests)
- [ ] Program alignment (work serves business outcomes)

## LLM Model Selection

Paivot is vendor-agnostic and works with any LLM provider. Configure in `opencode.json`:

```json
{
  "models": {
    "default": "anthropic/claude-sonnet-4-5-20250929",
    "opus": "anthropic/claude-opus-4-6-20250514",
    "openai": "openai/gpt-4-turbo",
    "google": "google/gemini-2.0-flash-exp",
    "local": "ollama/qwen2.5-coder:32b"
  },
  "agent": {
    "pivotal-developer": {
      "model": "{models.opus}"
    }
  }
}
```

**Supported vendors:**
- Anthropic (Claude Opus, Sonnet, Haiku)
- OpenAI (GPT-4, GPT-4 Turbo, O1)
- Google (Gemini)
- AWS Bedrock
- Groq
- Azure OpenAI
- Local models (Ollama, LM Studio)

Choose based on your needs:
- **Claude Opus**: Best for complex reasoning (Sr. PM, Architect, Anchor)
- **Claude Sonnet**: Cost-effective for PM review, retro
- **GPT-4 Turbo**: Alternative for complex tasks
- **Gemini**: Google ecosystem integration
- **Local models**: Privacy, cost control

## Best Practices

- **Outcomes first** - technical details support outcomes
- **Challenge the user** - question assumptions, push back on unclear requirements
- **Sr PM embeds ALL context + testing requirements** - developers need nothing beyond the story
- **Orchestrator NEVER writes code** - spawns Developer agents
- **Developers MUST record proof** - PM uses evidence, not re-testing
- **Rejected stories prioritized first** - clear the queue before new work
- **Spikes for ambiguity** - don't guess, investigate
- **Other repos: read and file bugs only** - never modify external repos
- **Anchor validates reality at milestones** - not just process compliance but actual delivery

## Configuration

Check `.claude/paivot.local.md` (if migrating from Claude Code) or create `opencode-paivot.local.md` for parallelization limits:

```yaml
---
max_parallel_devs: 2   # Max Developer agents at once (default: 2)
max_parallel_pms: 1    # Max PM agents at once (default: 1)
---
```

The FSM also supports configuration via:

```bash
piv config set max_parallel_devs 3
piv config set max_parallel_pms 2
piv config set decomposition per-milestone
piv config get
```

## Labels

| Label | Meaning |
|-------|---------|
| `delivered` | Developer done, awaiting PM review |
| `accepted` | PM approved, story closed |
| `rejected` | PM failed AC, story reopened |
| `cant_fix` | 5+ rejections, needs human intervention |
| `milestone` | Epic with new demoable functionality |
| `tdd-strict` | Requires 100% unit test coverage |
| `run-all-tests` | Run full test suite, not narrow scope |
| `contains-learnings` | Story has LEARNINGS in notes |
| `ci-fix` | CI infrastructure fix in progress (lock) |
| `gap-fix` | Fixes gaps found by Anchor milestone review |
