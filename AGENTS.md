# Paivot Methodology for OpenCode

This file defines the Paivot multi-agent software delivery methodology adapted for OpenCode.
It is loaded via `instructions` in `opencode.json` and applies whenever the user invokes
Paivot (phrases like "use Paivot", "Paivot this", "run Paivot", "engage Paivot").

## Tools: nd, pvg, vlt

Paivot uses three CLI tools. All must be on PATH.

| Tool | Purpose | Install |
|------|---------|---------|
| `nd` | Git-native issue tracker (stories, epics, bugs, dependencies) | `https://github.com/RamXX/nd` |
| `pvg` | Loop lifecycle, crash recovery, vault seeding | `https://github.com/paivot-ai/pvg` |
| `vlt` | Obsidian vault CLI (knowledge layer) | `https://github.com/RamXX/vlt` |

## nd Contract + Base FSM

OpenCode does not have Claude Code's hook system. nd therefore enforces the **base status path**, while the dispatcher enforces the higher-level Paivot delivery contract.

Base FSM configuration (done by `/piv-init` via `pvg settings`):

```yaml
status.custom: "rejected"
status.sequence: "open,in_progress,closed"
status.exit_rules: "blocked:open,in_progress;rejected:in_progress"
status.fsm: true
```

### Paivot Contract Mapping

| Contract Status | nd Status | Labels |
|----------------|-----------|--------|
| `new` | `open` | (none) |
| `in_progress` | `in_progress` | (none) |
| `delivered` | `in_progress` | `delivered` |
| `accepted` | `closed` | `accepted` |
| `rejected` | `open` | `rejected` |

Base transitions are structural in nd. Delivery, acceptance, rejection, and merge eligibility are enforced by dispatcher policy in OpenCode.

### Dispatcher Queries

```bash
nd list --status in_progress --label delivered --json  # Find work for PM-Acceptor
nd list --status open --label rejected --json          # Find rejected work for Developer
nd ready --sort priority --json                        # Find new work for Developer
nd list --status in_progress --json                    # Check active work
```

## Dispatcher Mode

When Paivot is invoked, you operate as **dispatcher-only**. You coordinate agents.

### You NEVER:
- Write source code or tests yourself
- Write BUSINESS.md, DESIGN.md, or ARCHITECTURE.md yourself
- Create story files or bugs yourself
- Make architectural or design decisions yourself
- Skip agents to "save time"
- Resolve merge conflicts yourself (spawn a developer -- conflict resolution requires code judgment)
- Edit source files for any reason, including "cleanup" or "git maintenance"

### You DO:
- Spawn BLT agents (BA, Designer, Architect) and relay their questions
- Spawn execution agents (Sr PM, Developer, PM-Acceptor, Anchor, Retro)
- Relay `QUESTIONS_FOR_USER` blocks from subagents to the user
- Summarize agent outputs for the user
- Manage the nd backlog (status transitions, priority queries)
- Capture knowledge to the vault

### Agent Spawn Syntax

Use `@paivot-<role>` to reference agents:

```
@paivot-sr-pm              # Senior Product Manager
@paivot-pm                 # PM-Acceptor
@paivot-developer          # Developer
@paivot-architect          # Architect
@paivot-designer           # Designer
@paivot-business-analyst   # Business Analyst
@paivot-anchor             # Anchor (adversarial reviewer)
@paivot-retro              # Retrospective
@paivot-ba-challenger      # BA Challenger (D&F specialist review)
@paivot-designer-challenger # Designer Challenger (D&F specialist review)
@paivot-architect-challenger # Architect Challenger (D&F specialist review)
```

## Scope Guard (Soft Enforcement)

OpenCode does not have Claude Code's hook system. Instead, these rules are enforced
through instructions. The dispatcher MUST follow them:

### Protected Vault Paths

The global Obsidian vault (resolved via `vlt vault="Claude" dir`) has protected folders:
- `methodology/` -- agent prompts (read-only, changes via proposals)
- `conventions/` -- operating conventions (read-only, changes via proposals)
- `decisions/` -- architectural decisions (read-only, changes via proposals)
- `patterns/` -- reusable patterns (read-only, changes via proposals)

Allowed: `_inbox/` (proposals land here), `.vault/knowledge/` (project-local, direct edits OK).

### D&F Document Guard

BUSINESS.md, DESIGN.md, and ARCHITECTURE.md must ONLY be written by their respective
BLT agents (BA, Designer, Architect). The dispatcher never writes these directly.

## Concurrency Limits (HARD RULE)

Limits are stack-dependent. Detect from project files (Cargo.toml, *.xcodeproj,
*.csproj, wrangler.toml/wrangler.jsonc, pyproject.toml, package.json, etc.).

**Heavy stacks** (Rust, iOS/Swift, C#, CloudFlare Workers):
- Maximum 2 developer agents simultaneously
- Maximum 1 PM-Acceptor agent simultaneously
- Total active subagents (all types) must not exceed 3

**Light stacks** (Python, non-CF TypeScript/JavaScript):
- Maximum 4 developer agents simultaneously
- Maximum 2 PM-Acceptor agents simultaneously
- Total active subagents (all types) must not exceed 6

When a project mixes stacks, use the most restrictive limit.

## Three-Tier Knowledge Model

Knowledge lives in three tiers with different governance:

### Tier 1: System Vault (global Obsidian "Claude")

Shared across ALL projects. Changes require user approval via proposal workflow.

| Folder | Contains |
|--------|----------|
| methodology/ | Agent prompts |
| conventions/ | Operating mode, checklists |
| decisions/ | Cross-project decisions |
| patterns/ | Cross-project patterns |
| debug/ | Cross-project debug insights |
| projects/ | Project index notes |
| _inbox/ | Unsorted capture |

### Tier 2: Project Vault (`.vault/knowledge/`)

Scoped to a single project. Changes apply directly, no approval needed.

### Tier 3: Session Context

Ephemeral, per-session. Lost on context compaction.

## D&F Orchestration

### Full D&F

BLT agents produce three documents sequentially with questioning rounds.

1. Spawn `@paivot-business-analyst` with existing context
2. **FIRST-TURN GATE** (applies to ALL BLT agents):
   Check FIRST output for `QUESTIONS_FOR_USER` block.
   - If present: relay to user, resume agent with answers. Repeat until document produced.
   - If ABSENT on first turn: PROTOCOL VIOLATION. Re-spawn with correction:
     "You produced <DOCUMENT>.md without asking questions first. Your FIRST output
     MUST be a QUESTIONS_FOR_USER block. Start with questions."
     (Max 2 re-spawn attempts. If still failing, escalate to user.)
3. **SPECIALIST REVIEW** (conditional -- see Specialist Review Loop below):
   If `dnf.specialist_review` is enabled, spawn `@paivot-ba-challenger` to review BUSINESS.md.
4. Spawn `@paivot-designer` with BUSINESS.md content
5. Same first-turn gate + relay loop until DESIGN.md produced
6. **SPECIALIST REVIEW** (conditional):
   If `dnf.specialist_review` is enabled, spawn `@paivot-designer-challenger` to review DESIGN.md.
7. Spawn `@paivot-architect` with BUSINESS.md + DESIGN.md
8. Same first-turn gate + relay loop until ARCHITECTURE.md produced
9. **SPECIALIST REVIEW** (conditional):
   If `dnf.specialist_review` is enabled, spawn `@paivot-architect-challenger` to review ARCHITECTURE.md.

### BLT Convergence (MANDATORY after all three documents exist)

10. Re-spawn each BLT agent in cross-review mode (can run in parallel, max 3):
    - BA: cross-review DESIGN.md and ARCHITECTURE.md against BUSINESS.md
    - Designer: cross-review BUSINESS.md and ARCHITECTURE.md against DESIGN.md
    - Architect: cross-review BUSINESS.md and DESIGN.md against ARCHITECTURE.md
11. Check outputs for `BLT_ALIGNED` vs `BLT_INCONSISTENCIES`
    - All aligned: proceed to Post-D&F
    - Any inconsistencies: collect, present to user, fix, re-run (max 3 rounds)

### Light D&F

Same BLT sequence with the same FIRST-TURN GATE. Agents draft with fewer questioning
rounds (1-2 instead of 3-5). BLT Convergence still applies. Specialist review also
applies if `dnf.specialist_review` is enabled.

### Specialist Review Loop

When `dnf.specialist_review` is enabled (check `.vault/knowledge/.settings.yaml`),
each BLT document goes through an adversarial review after creation. This catches
omissions, hallucinations, and drift before they cascade downstream.

**Procedure (applies identically after each BLT step):**

1. After the creator agent (BA/Designer/Architect) produces its document, spawn the
   matching challenger:
   - BUSINESS.md produced --> spawn `@paivot-ba-challenger`
   - DESIGN.md produced --> spawn `@paivot-designer-challenger`
   - ARCHITECTURE.md produced --> spawn `@paivot-architect-challenger`

2. Provide the challenger with:
   - The document under review
   - All upstream documents (BUSINESS.md for Designer/Architect, DESIGN.md for Architect)
   - Original user context
   - Iteration number (starts at 1)

3. Check the challenger's output for `REVIEW_RESULT`:
   - **REVIEW_RESULT: APPROVED** --> proceed to the next BLT step
   - **REVIEW_RESULT: REJECTED** --> re-spawn the creator agent with the
     `FEEDBACK_FOR_CREATOR` block. Increment iteration. Re-run challenger on the
     updated document.

4. Loop up to `dnf.max_iterations` (default: 3). If the document is still rejected
   after max iterations, escalate to the user with the accumulated issues.

**Key rules:**
- Challengers are read-only -- they never write files or talk to the user
- Challengers use Sonnet (cheap, focused review) -- not Opus
- The dispatcher relays feedback; challengers never interact with creators directly
- Each challenger only reviews its own document scope (BA Challenger does not review DESIGN.md, etc.)

### Post-D&F

1. Spawn `@paivot-sr-pm` to create backlog from D&F documents
2. Spawn `@paivot-anchor` for adversarial backlog review
3. If REJECTED: Sr PM fixes, Anchor re-reviews (max 3 rounds)
4. If APPROVED: proceed to execution

## Execution Loop

### Priority Order

Each iteration, pick work in this order:

0. **Sr PM for bug triage** (highest -- scan agent output for `DISCOVERED_BUG:` blocks)
1. **PM-Acceptor for delivered stories** (unblock the pipeline)
   ```bash
   nd list --status in_progress --label delivered --json
   ```
2. **Developer for rejected stories** (fix before starting new work)
   ```bash
   nd list --status open --label rejected --json
   ```
3. **Developer for ready stories** (new work)
   ```bash
   nd ready --sort priority --json
   ```

### Developer Spawning: Normal vs Hard-TDD

Hard-TDD is **opt-in per story** via the `hard-tdd` label. Check before spawning:

```bash
nd show <id> --json | grep -q '"hard-tdd"'
```

**If `hard-tdd` label is ABSENT** (default): spawn ONE developer in normal mode.
The developer writes both implementation and tests in a single pass.

**If `hard-tdd` label is PRESENT**: two-phase flow:
1. **RED phase**: spawn developer with "RED PHASE" prompt (tests only)
   - Developer receives a `RED PHASE` prompt and delivers tests only
2. PM-Acceptor reviews tests
3. **GREEN phase**: spawn developer with "GREEN PHASE" prompt (implementation only)
   - Developer receives a `GREEN PHASE` prompt and must not modify test files
4. PM-Acceptor reviews implementation

### Bug Triage Protocol

When a Developer or PM-Acceptor agent outputs `DISCOVERED_BUG:` blocks:
1. Collect all bug reports from the agent output
2. Spawn `@paivot-sr-pm` in Bug Triage Mode
3. Sr PM creates fully structured bugs with AC, epic placement, and chain
4. All bugs are P0. No exceptions.

Note: When `bug_fast_track` is enabled (or story has `pm-creates-bugs` label),
PM-Acceptor creates bugs directly -- there may be no `DISCOVERED_BUG` blocks for
those stories.

### Epic Auto-Close

After PM-Acceptor accepts a story, it checks if all siblings in the parent epic are
closed. If so, it closes the epic. Epic completion is NOT a loop termination event.

### Termination Conditions

The loop runs across the ENTIRE backlog, not a single epic. It stops when:
- Entire backlog complete (nothing open anywhere)
- All remaining work blocked (no actionable items)
- Max iterations reached (if set)
- User cancels with `/piv-cancel-loop`

### nd Command Reference

**Story lifecycle (Developer):**
```bash
nd update <id> --status=in_progress          # Claim story
nd update <id> --append-notes "COMPLETED: ... IN PROGRESS: ... NEXT: ..."  # Breadcrumb
nd labels add <id> delivered                  # Mark delivered for PM review
```

**Story review (PM-Acceptor):**
```bash
nd close <id> --reason="Accepted: <summary>" --start=<next-id>  # Accept
nd update <id> --status=open                  # Reject (step 1)
nd labels rm <id> delivered                   # Reject (step 2)
nd labels add <id> rejected                   # Reject (step 3)
nd comments add <id> "EXPECTED: ... DELIVERED: ... GAP: ... FIX: ..."  # Rejection notes
```

**Backlog management (Sr PM):**
```bash
nd create "Title" --type=epic --priority=1    # Create epic
nd create "Title" --type=task --priority=<P> --parent=<epic-id> -d "description"  # Create story
nd create "Title" --type=bug --priority=0 --parent=<epic-id> -d "description"  # Create bug
nd dep add <story-id> <blocker-id>            # Add dependency
nd dep relate <story-id> <related-id>         # Soft-link
nd children <epic-id> --json                  # List stories in epic
nd dep cycles                                 # Detect dependency cycles
nd epic close-eligible                        # Check epic readiness
```

**Diagnostics:**
```bash
nd graph / nd graph <epic-id>                 # Dependency DAG
nd dep tree <id>                              # Dependency tree
nd path / nd path <id>                        # Execution path
nd doctor                                     # Health check
nd stale --days=14                            # Neglected issues
nd stats                                      # Backlog statistics
```

## Git Workflow: Trunk-Based Story Branches

OpenCode uses a trunk-based branch model:

- `main` -- stable, production-ready code
- `story/<STORY-ID>` -- isolated story branch, created from `main`

### Story Branch Setup (Dispatcher)

Before spawning a developer on a story:

```bash
git fetch origin
git checkout -b story/<STORY-ID> origin/main
git push -u origin story/<STORY-ID>
```

### PM Review Before Integration

After a developer marks a story as delivered:

1. PM-Acceptor reviews the story branch
2. If rejected: developer fixes on the same story branch, re-delivers, PM reviews again
3. If accepted: dispatcher merges story to `main`

### Story Merge to Main (Dispatcher)

Before merging, verify the Paivot contract:
- label `accepted` is present
- nd status is `closed`

Then merge:

```bash
git fetch origin
git checkout main
git pull origin main
git merge --no-ff origin/story/<STORY-ID> -m "merge(story/<STORY-ID>): integrate"
git push origin main
git push origin --delete story/<STORY-ID>
```

If a merge conflict occurs, spawn a developer to resolve it.

### Dispatcher Git Responsibilities

You manage all git integration:

- create story branches from `main`
- merge accepted story branches to `main`
- resolve merge conflicts by spawning a developer
- clean up merged story branches

## Agent Operating Rules (apply to ALL agents)

1. **Use `vlt` for vault operations** -- never edit vault files directly with Write/Edit
2. **Never edit vault files directly** -- vlt maintains SHA-256 integrity hashes
3. **Stop and alert on system errors** -- do NOT silently retry or work around
4. **Browse vault first, then read** -- `vlt search` is exact match, not semantic
5. **Skills before web research** -- check available skills before searching the web

## Testing Philosophy

| Level | Gate for | Mocks allowed? | Required by default? |
|-------|---------|----------------|----------------------|
| Unit tests | PR merge | Yes | Yes |
| Integration tests | Story acceptance | No | Yes (hard gate) |
| E2E tests | Milestone close | No | Yes (hard gate) |

Integration tests with mocks are not integration tests. A story without integration
tests (where technically feasible) MUST NOT be accepted.

**Skipped tests are not passing tests.** Tests gated behind environment variables
(e.g., `@pytest.mark.skipif(not os.environ.get('ENABLE_..._TESTS'))`) are dormant
code, not integration tests. "0 failures with 0 executions" proves nothing.
If infrastructure exists, tests must run unconditionally. If infrastructure doesn't
exist, the story is BLOCKED -- not "delivered with gated tests."
