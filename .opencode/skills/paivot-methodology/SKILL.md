---
name: paivot-methodology
description: >-
  Use when working on projects with Paivot methodology, D&F (Discovery & Framing),
  backlog management, story execution, or when .beads/ directory exists.
  Covers orchestrator rules, agent spawning, testing philosophy, delivery workflow.
  Auto-activates on pivotal/paivot patterns or when bd commands are used.
version: 1.0.0
license: MIT
compatibility: ["go", "typescript", "python", "javascript", "rust"]
---

# Paivot - Modified Pivotal Methodology for AI Agents

This is the working agreement for AI agents using beads (bd) to run the Paivot Methodology. Optimized for ephemeral, short-context agent execution with testing requirements driven by story content.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work (PM only)
bd sync               # Sync with git
```

> **bd syntax note**: Prefer short flags (`-t`, `-p`, `-d`) over long flags. bd CLI evolves frequently - check `bd --help` for current syntax.

> **Note**: In Paivot, only PMs close stories. Developers mark stories as `delivered` instead. See "Delivery Workflow" below.

## Overview

- **Beads is crucial** - All state, context, decisions, and rejection history are tracked in beads. Without beads, the methodology cannot function.
- The backlog is the single source of truth owned by the PM.
- **Stories are self-contained execution units** - Sr. PM/PM embeds all context into stories, including testing requirements.
- **Default testing standard**: Reasonable unit coverage + **mandatory integration tests** (no mocks, real API calls).
- **TDD with 100% unit coverage** is available when explicitly specified in the story.
- **No skipped tests** - if a test has a blocker (missing API key, unavailable service), the story is blocked and user alerted.
- Stories must be INVEST (Independent, Negotiable, Valuable, Estimable, Small, Testable) and atomic. **Independence is structurally critical**: it enables safe parallel execution. When stories are truly independent -- touching different files, different components, no shared mutation -- the orchestrator can dispatch multiple Developer agents simultaneously. Stories with overlapping file scopes require explicit `blocks` dependencies to force sequential execution.

## Agent Execution Model

**CRITICAL CONSTRAINT: Agents CANNOT spawn subagents.** Only the orchestrator (main agent) can spawn agents.

**The orchestrator (main agent) is the DISPATCHER. It:**
- NEVER writes code itself - only orchestrates via subagents
- Spawns Developer agents for story implementation
- Spawns PM-Acceptor agents for delivery review
- Spawns Sr. PM agent for story/epic CRUD, PM for bugs
- Manages parallelization and agent budget directly

**FSM HARD ENFORCEMENT (when piv is initialized):**

The PreToolUse hook enforces the FSM at the tool level:
- Calls `piv next` before every agent spawn
- **Blocks any action that doesn't match** FSM recommendation
- **Blocks wrong story** - must work on FSM-prioritized story
- **Blocks excess spawns** - respects parallelization limits

The orchestrator CANNOT bypass the FSM - the hook will reject mismatched actions.

### Concurrency Model

Check `.local.md` (or platform config) for parallelization limits (or use defaults):

```yaml
---
max_parallel_devs: 2   # Max Developer agents at once
max_parallel_pms: 1    # Max PM agents at once
---
```

- **Default limits:** `max_parallel_devs=2`, `max_parallel_pms=1`
- **Orchestrator respects these limits** - spawns up to max, remaining work handled next iteration
- **Never parallelize** resource-intensive work (GPU, local LLM inference, heavy integration tests)
- **Configure via** `/piv-config` or edit config directly

### Long-Running Session Mode

When user says "this will be a long-running session" (or similar: overnight, unattended):

**Rules:**
- **ALL work is sequential** - no parallelization whatsoever
- **Run until complete or blocked** - only stop when all work is complete or pipeline is blocked
- **No user interaction expected** - don't pause for questions
- **Log progress in beads** - update story notes so user can review later

### Agent Spawning Rules

| Role | How to Invoke | Lifespan | Scope |
|------|---------------|----------|-------|
| Sr. PM | `@pivotal-sr-pm` | Ephemeral | Story/Epic CRUD |
| PM | `@pivotal-pm` | Ephemeral | Bug filing |
| PM-Acceptor | `@pivotal-pm` | Ephemeral | One story |
| Developer | `@pivotal-developer` | Ephemeral | One story |
| Retro (Epic) | `@pivotal-retro` | Ephemeral | One milestone epic |
| Retro (Final) | `@pivotal-retro` | Ephemeral | Entire project |
| Anchor (Milestone) | `@pivotal-anchor` | Ephemeral | One milestone epic |
| Anchor (Backlog) | `@pivotal-anchor` | Ephemeral | Full backlog |

**The orchestrator (main agent) MUST:**
- Spawn these as subagents using agent invocation syntax
- NEVER "become" or "act as" these roles itself
- NEVER write code itself - always spawn a Developer agent
- Spawn Sr. PM for story/epic CRUD (create/update/delete epics or stories)
- Spawn PM for bug filing (cheaper than Sr. PM)

**CRITICAL - After Developer Returns:**

When a Developer agent completes and returns results to the orchestrator:

1. **IGNORE all diagnostics** - compilation errors, test failures, warnings are NOT your concern
2. **Call `piv next`** - FSM will recommend spawning PM if story was delivered
3. **Spawn exactly what FSM says** - PM-Acceptor evaluates the delivery, not you
4. **ONLY if PM rejects** does FSM recommend spawning a new Developer

**The orchestrator is a DISPATCHER, not a JUDGE.** You do not evaluate code quality, test results, or compilation status. The PM-Acceptor makes all accept/reject decisions.

**HARD ENFORCEMENT:** If you try to spawn a Developer after seeing errors, the hook will BLOCK you (unless enforcement is disabled via `/piv-disable`):
```
BLOCKED BY FSM: Wrong agent type.
You requested: spawn_developer
FSM recommends: spawn_pm
```

**VIOLATIONS (orchestrator must NEVER do these):**
- See errors and spawn a Developer to "fix" them (PM decides what needs fixing)
- Skip PM-Acceptor because "there are obvious issues" (PM evaluates ALL deliveries)
- Make judgments about whether code "works" (that's PM's job)

**Correct sequence:**
```
Developer returns -> Orchestrator spawns PM-Acceptor -> PM accepts OR rejects
                                                              |
                                            If rejected: Orchestrator spawns new Developer
```

**Wrong sequence:**
```
Developer returns -> Orchestrator sees errors -> Orchestrator spawns Developer to fix
                     ^-- THIS IS THE VIOLATION (orchestrator judged, bypassed PM)
```

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

**Example loop:**
```python
# Anchor returns REJECTED with 6 gaps
while anchor_result == "REJECTED":
    # Spawn Sr. PM to fix ALL gaps (orchestrator never fixes directly)
    @pivotal-sr-pm
    # Task: Address Anchor gaps: {gaps_list}. Update affected stories.

    # Re-spawn Anchor to review fixes
    @pivotal-anchor
    # Task: Review backlog for gaps after Sr. PM fixes.

# Only NOW can execution begin
@pivotal-developer
```

**VIOLATIONS (orchestrator must NEVER do these):**
- Fix gaps by running `bd update` or `bd comments add` directly
- Announce "spawning Developer" before Anchor returns APPROVED
- Skip the re-review loop after Sr. PM fixes gaps
- Treat "gaps addressed" as equivalent to "Anchor approved"

### Git Workflow: Trunk-Based Development (MANDATORY)

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

**Orchestrator Workflow:**
```bash
# Daily workflow - orchestrator ensures all agents stay synchronized
git checkout beads-sync
git pull --rebase origin beads-sync

# Spawn developers - they ALL commit to beads-sync
@pivotal-developer
# Task: Implement story bd-xxxx. ALL commits go to beads-sync. Record proof.

# After work completes, ensure sync before ending session
bd sync
git pull --rebase origin beads-sync
git push origin beads-sync
git status  # Verify: "up to date with origin/beads-sync"
```

**Epic Completion: NO branch cleanup (no epic branches exist)**

When epic completes (all stories accepted):

```bash
# 1. VERIFY complete
bd list --parent <epic-id> --status open,in_progress --json  # Must be empty

# 2. SYNC beads state
bd sync

# 3. Ensure beads-sync is pushed
git checkout beads-sync
git pull --rebase origin beads-sync
git push origin beads-sync

# 4. RUN RETRO (for milestone epics)
bd show <epic-id> --json | jq -r '.labels[]' | grep -q 'milestone' && \
  echo "Milestone epic complete - spawn pivotal-retro agent"

# 5. RUN ANCHOR MILESTONE REVIEW (MANDATORY after retro)
# Anchor validates the milestone actually delivered real value
# See "Milestone Validation Protocol" section for details
```

**Merge to Main (Periodic, Human-Driven):**

Beads-sync content is merged to main periodically via PR (e.g., daily, per milestone):
```bash
# Typically via GitHub UI or:
gh pr create --base main --head beads-sync \
  --title "Sync: Epic <epic-id> complete" \
  --body "Completed work for epic <epic-id>: <title>"

# After PR approved and merged:
git checkout main && git pull origin main
git checkout beads-sync && git rebase main && git push origin beads-sync
```

**NEVER create feature branches per story.**
**ALWAYS commit to beads-sync.**
**ALWAYS run retro for milestone epics** - learnings compound over time.
**ALWAYS run Anchor milestone review** - validates real delivery, not just process compliance.

## Agent Descriptions

- **Orchestrator (main agent)**: The dispatcher. NEVER writes code. Spawns all other agents. Manages execution loop, agent budget, story dispatch, and epic lifecycle.
- **Sr. PM**: Ephemeral subagent for backlog CRUD. Creates/updates/deletes epics and stories. Embeds all context AND testing requirements into stories. **MUST review `.learnings/` before creating/modifying stories** and incorporate relevant insights.
- **Developer**: Ephemeral subagent. Implements the story. **MUST record proof of passing tests** in delivery notes. Marks stories as `delivered` (NOT closed). Then disposed.
- **PM-Acceptor**: Ephemeral subagent. **The final gatekeeper**. Uses **evidence-based review** - relies on developer's recorded proof rather than re-running tests. Closes if accepted or reopens with detailed rejection notes. Then disposed.
- **Retro**: Ephemeral subagent. **Spawned after milestone epic completion**. Extracts LEARNINGS from all accepted stories, identifies patterns, distills actionable insights, writes to `.learnings/` directory. Then disposed.
- **Anchor (Milestone Review)**: Ephemeral subagent. **Spawned after retro completes for milestone epics**. Validates the milestone actually delivered real business value. Inspects tests for mocks (forbidden), verifies skills were consulted, checks acceptance criteria against reality. Returns VALIDATED or GAPS_FOUND. Then disposed.

### Delivery Workflow (CRITICAL)

```
Developer: bd label add <id> delivered
Developer: bd update <id> --notes "DELIVERED: [PROOF SECTION - see below]"
(Story stays in_progress with delivered label - developer does NOT close)

PM-Acceptor reviews (evidence-based):
  - Uses developer's proof instead of re-running tests (unless doubt exists)
  - Accept: bd label remove <id> delivered && bd label add <id> accepted && bd close <id> --reason "Accepted: [summary]"
  - Reject: bd label remove <id> delivered && bd label add <id> rejected && bd update <id> --status open --notes "REJECTED [YYYY-MM-DD]: ..."
```

**Developer's PROOF section MUST include:**
```
DELIVERED:
- CI Results: lint PASS, test PASS (XX tests), integration PASS (XX tests), build PASS
- Coverage: XX% (or specific coverage report output)
- Commit: <sha> pushed to origin/beads-sync
- Test Output: [paste relevant test output or summary]

LEARNINGS: [optional - gotchas, patterns discovered]
```

## Testing Philosophy

| Test Type | Purpose | Mocks OK? | Required For |
|-----------|---------|-----------|--------------|
| **Unit** | Code quality | YES | 80% coverage |
| **Integration** | Real functionality | **NO** | Story completion |
| **E2E** | Full system works | **NO** | Milestones |

**Key principles:**
- **Mocks ONLY in unit tests** - unit tests prove code quality, not functionality
- **Integration tests are what matter** - real API calls, real DBs, no mocks. Cannot be "delivered" without these.
- **E2E tests gate milestones** - must be demoable with real requests hitting real code
- **`tdd-strict` label** = 100% unit coverage + integration tests

**Test scope: NARROW by default.** Run only tests affected by the story, not the full suite. Full test runs are expensive and slow. Only run all tests when:
- Story explicitly requires `run-all-tests`
- Story is in a milestone epic
- Story touches shared infrastructure

**NEVER soften or simplify tests** to work around external issues. If an external dependency has problems, BLOCK the story. Softening tests masks the real issue.

## Discovery & Framing

D&F is an **outcomes-driven** process. All D&F documents live in `docs/`:
- `docs/BUSINESS.md` - Business outcomes, goals, constraints
- `docs/DESIGN.md` - User needs, UX/DX, wireframes
- `docs/ARCHITECTURE.md` - Technical approach, system design

**The Process**:
1. **Facilitator** engages user, extracts outcomes, goals, constraints
2. **BA** (via subagent) captures business outcomes -> BUSINESS.md
3. **Designer** (via subagent) captures user needs, DX -> DESIGN.md
4. **Architect** (via subagent) captures technical approach -> ARCHITECTURE.md
5. **Adversarial Backlog Creation** (see "Backlog Review Gate" section):
   - **Sr PM** creates backlog with walking skeletons, vertical slices, embedded context
   - **Anchor** reviews looking for gaps
   - If REJECTED: **Sr PM fixes gaps**, then **Anchor re-reviews** (orchestrator manages loop, never fixes directly)
   - **Loop continues** until Anchor returns APPROVED
7. **Green light for execution** - ONLY after Anchor explicitly returns APPROVED (not "gaps addressed")

**Note on brownfield projects**: Sr PM can be invoked directly without requiring full D&F.

## Execution Loop

**When piv is initialized, the orchestrator MUST use `piv next` to determine actions:**

```python
while True:
    # 1. ALWAYS call piv next first - it decides what to do
    result = shell("piv next")
    action_json = json.loads(result)

    action = action_json["action"]
    story_id = action_json.get("story_id")

    # 2. Check terminal states
    if action == "complete":
        print("All work complete")
        break
    if action == "wait":
        sleep(5)
        continue

    # 3. Execute EXACTLY what piv says (hook enforces this)
    if action == "spawn_developer":
        @pivotal-developer
        # Task: Implement story {story_id}. ALL commits go to beads-sync. Record proof.

    elif action == "spawn_pm":
        @pivotal-pm
        # Task: Review delivered story {story_id}. Use developer's proof for evidence-based review.

    # 4. Loop continues - piv next determines priority order
```

**Priority order is enforced by FSM:**
1. PM review (delivered stories)
2. Rejected stories (need developer fix)
3. Ready stories (new work)

## Strict Role Boundaries

**Each agent ONLY does its job. Agents do NOT step outside their roles.**

| Agent | Does | Does NOT |
|-------|------|----------|
| Orchestrator | Spawn agents, manage execution loop, dispatch stories | Write code, manage backlog directly |
| Sr. PM | Create/update/delete stories and epics, embed context | Write code, implement stories |
| PM-Acceptor | Review deliveries, accept/reject stories, close accepted, capture test gap learnings, file bugs | Write code, create stories/epics |
| Developer | Implement assigned story, write tests, record proof, deliver | Close stories, modify backlog, modify other repos (read/file bugs only) |

**Failure Modes:**

| Situation | Response |
|-----------|----------|
| Story lacks context | STOP. Escalate to orchestrator. Do NOT guess. |
| Blocker encountered | Mark story BLOCKED. Alert orchestrator. |
| Asked to do something outside role | REFUSE. Explain which agent should be invoked. |
| Orchestrator asked to write code | REFUSE. Spawn a Developer agent instead. |
| Orchestrator asked to create stories/epics | Spawn Sr. PM agent. |
| Orchestrator asked to file bugs | Spawn PM agent (cheaper). |
| Bug found in external repo | READ and FILE BUG only. If story depends on fix, BLOCK and wait. |
| Bug slipped through tests | PM adds LEARNING section, OUTPUTS to user immediately (non-blocking). |
| Developer returns with errors/warnings | IGNORE. Call `piv next`. Spawn what FSM says (PM). Hook blocks wrong agent. |
| Orchestrator sees compilation errors | DO NOT JUDGE. Call `piv next`. Hook will BLOCK if you try spawn_developer. |
| Orchestrator tempted to spawn Developer for "obvious fix" | REFUSE. Hook enforces: FSM recommends spawn_pm, not spawn_developer. |
| Anchor returns REJECTED | Spawn Sr. PM to fix gaps, then re-spawn Anchor. NEVER fix directly. NEVER skip re-review. |
| Orchestrator tempted to "quickly fix" backlog gaps | REFUSE. Spawn Sr. PM. The loop exists for a reason. |

## Issue Lifecycle & Labels

**Statuses:** `open`, `in_progress`, `closed`, `blocked`

**Labels:**
- `delivered` - developer done, awaiting PM review
- `accepted` - PM verified, story closed (audit trail)
- `rejected` - PM failed AC, story back to `open`
- `cant_fix` - 5+ rejections, needs user intervention
- `milestone` - new demoable functionality
- `tdd-strict` - requires 100% test coverage
- `ci-fix` - CI infrastructure fix in progress (lock)

## Test Gap Learnings

**When a bug is discovered that should have been caught by tests, PM-Acceptor MUST:**

1. Add a LEARNING section to the story notes:
   - What bug slipped through
   - What type of test should have caught it
   - Why our tests missed it (root cause)
   - Recommended test additions

2. **OUTPUT to user immediately** - don't bury in notes. Format:
   ```
   [TEST GAP LEARNING] Bug in story <id>:
     Bug: <description>
     Root cause: <why tests missed it>
     Recommendation: <what to add>
   ```

3. This is **NON-BLOCKING** - pipeline continues, learnings are captured for later methodology improvement.

**Purpose:** Improve testing methodology over time by capturing test gaps while fresh.

## Retrospective and Learnings Lifecycle

### When Retro Runs

**Mode 1: Epic Retro - After each milestone epic**

Orchestrator spawns Retro agent after every successfully completed MILESTONE epic:

```python
# After all stories in milestone epic are accepted
if epic.has_label('milestone') and epic.all_stories_accepted():
    @pivotal-retro
    # Task: Run retrospective for completed epic {epic.id}. Extract learnings and produce actionable insights.
```

**Mode 2: Final Project Retro - At project end**

Orchestrator spawns Retro agent when the ENTIRE PROJECT is complete (all epics done):

```python
# When all epics are complete and project is finished
if all_epics_complete and project_ending:
    @pivotal-retro
    # Task: Run FINAL PROJECT retrospective. Review all accumulated learnings and identify systemic insights that transcend this project.
```

**Final retro behavior:**
- Reviews ALL learnings in `.learnings/` directory
- Identifies patterns that transcend this specific project
- **ONLY outputs recommendations if systemic insights exist**
- If everything is project-specific, completes silently without recommendations
- Systemic = methodology/process improvements that apply to ANY project

### What Retro Does

1. **Extracts LEARNINGS** from all accepted stories in the epic
2. **Identifies patterns** across multiple learnings
3. **Distills actionable insights** - specific, forward-looking recommendations
4. **Writes to `.learnings/`** directory:
   - Category files: `testing.md`, `architecture.md`, `process.md`, etc.
   - Epic retro doc: `<epic-id>-retro.md`
5. **Commits learnings** to git
6. **Flags backlog impact** if insights should affect existing stories

### Learnings Directory Structure

```
.learnings/
  index.md              # Index of all insight files
  testing.md            # Testing-related insights
  architecture.md       # Architecture insights
  tooling.md            # Tooling insights
  process.md            # Process insights
  external-deps.md      # External dependency insights
  performance.md        # Performance insights
  <epic-id>-retro.md    # Full retro for specific epic
```

### Learnings Incorporation Gate (HARD FSM GATE)

After every retro, the FSM enters `LEARNINGS_REVIEW`. **Execution is blocked** until the Sr. PM incorporates learnings:

1. `piv next` returns `spawn_sr_pm` with reason about incorporating learnings
2. Sr. PM reads `.learnings/<epic-id>-retro.md` and categorized insight files
3. Sr. PM queries all open stories (`bd list --status open --json`)
4. For each story, assesses whether any learnings are relevant
5. Updates affected stories with new embedded context (`bd update <id> --notes "..."`)
6. Reports what was changed and why
7. Orchestrator records `piv event learnings_incorporated`
8. FSM transitions back to `EXECUTING`

**Flow (default, all-at-once):**
```
RETRO_RUNNING -> retro_complete -> LEARNINGS_REVIEW -> learnings_incorporated -> EXECUTING
```

**Flow (per-milestone, when undecomposed milestones exist):**
```
LEARNINGS_REVIEW -> learnings_incorporated -> MILESTONE_DECOMPOSITION -> milestone_decomposed -> MILESTONE_ANCHOR_REVIEW -> milestone_stories_approved -> EXECUTING
```

When `piv config set decomposition per-milestone` is active:
- The Sr. PM creates all epics during D&F but decomposes stories for only the first milestone
- After each milestone completes (retro + learnings), the next milestone gets decomposed
- Decomposed stories go through Anchor review before execution resumes
- If Anchor rejects, Sr. PM revises and resubmits (same loop as initial backlog review)
- When no undecomposed milestones remain, the flow falls through to EXECUTING as normal

### How Sr. PM Uses Learnings

**Sr. PM MUST review `.learnings/` before creating or modifying ANY stories:**

1. **Check for learnings directory**
2. **Read critical insights** from each category file
3. **Incorporate into new stories** - add as embedded context
4. **Assess backlog impact** - if a learning should affect existing stories:
   - Find affected stories
   - Update with new context
   - Document what was changed

### Learnings Flow

```
Developer captures LEARNINGS in delivery notes
           |
           v
PM-Acceptor may add TEST GAP LEARNING when bugs slip through
           |
           v
[Milestone Epic Completes]
           |
           v
Retro agent extracts and analyzes all learnings (Epic Mode)
           |
           v
Insights written to .learnings/ directory
           |
           v
FSM enters LEARNINGS_REVIEW (HARD GATE - execution blocked)
           |
           v
Sr. PM reads retro output + categorized insight files
           |
           v
Sr. PM updates ALL open stories that benefit from new insights
           |
           v
piv event learnings_incorporated
           |
           v
[if per-milestone & undecomposed milestones:]
  -> MILESTONE_DECOMPOSITION: Sr. PM decomposes next milestone
  -> MILESTONE_ANCHOR_REVIEW: Anchor reviews new stories
  -> milestone_stories_approved -> EXECUTING
           |
[else: FSM returns to EXECUTING directly]
           |
           v
ANCHOR MILESTONE REVIEW (validates real delivery)
           |
           v
IF gaps found:
  -> Sr. PM creates new stories to fill gaps
  -> Gaps must be addressed before next milestone
           |
           v
Future work benefits from accumulated knowledge
           |
           v
[Project Completes - All Epics Done]
           |
           v
Final Project Retro reviews ALL learnings
           |
           v
IF systemic insights found:
  -> Output recommendations to user
ELSE:
  -> Complete silently
```

## Milestone Validation Protocol (MANDATORY)

**After EVERY milestone epic retro, the Anchor MUST validate the completed work.** This is not optional. The Anchor brings fresh, adversarial eyes to answer: "Did we ACTUALLY deliver what we promised, or did we just check boxes?"

### Purpose

The retro captures learnings. The Anchor validates reality:
- Did the epic deliver its business value?
- Do the tests prove real functionality (not mocked)?
- Were skills actually consulted (not assumed)?
- Were corners cut?
- Does this align with program objectives?

### When Anchor Milestone Review Runs

```python
# After retro completes for a milestone epic
if epic.has_label('milestone') and retro_complete:
    @pivotal-anchor
    # Task: MILESTONE REVIEW for completed epic {epic.id}.
    #
    # Epic: {epic.title}
    # Business Value: {epic.business_value}
    #
    # Review the learnings from the retro at .learnings/{epic.id}-retro.md.
    #
    # Validate:
    # 1. Did this epic ACTUALLY deliver its stated business value?
    # 2. Inspect the tests - are there mocks in integration/E2E tests? (FORBIDDEN)
    # 3. Verify skills were consulted for domain-specific work (not assumed)
    # 4. Check acceptance criteria against reality - does it WORK, not just pass?
    # 5. Apply common sense - are we doing the right thing for the program?
    #
    # Output: VALIDATED or GAPS_FOUND with specific issues.
```

### What Anchor Validates (Post-Execution)

**1. Business Value Delivery**
- [ ] Epic's stated business value is actually realized
- [ ] Users can do what was promised (not "tests pass")
- [ ] Acceptance criteria are met in practice, not theory
- [ ] Demo would satisfy stakeholders

**2. Test Integrity (CRITICAL)**
- [ ] Integration tests have NO mocks (real API calls only)
- [ ] E2E tests use real execution (no fixtures)
- [ ] Tests prove functionality works, not just that code runs
- [ ] No "cheating" - tests aren't simplified to pass
- [ ] Coverage is meaningful, not just numbers

**3. Skills Consultation**
- [ ] Domain-specific work consulted relevant skills
- [ ] Technical approaches align with skill guidance
- [ ] Not assumed - verify skill was actually invoked
- [ ] Embedded context reflects skill knowledge

**4. No Corners Cut**
- [ ] Every story's AC is fully met (not "close enough")
- [ ] No TODOs left in code marked as complete
- [ ] No disabled tests or skipped assertions
- [ ] Error handling is real, not placeholder
- [ ] Edge cases are covered, not ignored

**5. Program Alignment**
- [ ] Work aligns with BUSINESS.md objectives
- [ ] Work supports program goals (not just epic goals)
- [ ] Technical decisions serve business outcomes
- [ ] Common sense applied beyond literal specs

### Anchor Milestone Review Output

**If VALIDATED:**
```
[MILESTONE VALIDATED] Epic <epic-id>: <Epic Title>

Business value: DELIVERED
Test integrity: VERIFIED (no mocks in integration/E2E)
Skills consulted: CONFIRMED
Implementation quality: COMPLETE

Proceed to next epic.
```

**If GAPS_FOUND:**
```
[MILESTONE GAPS FOUND] Epic <epic-id>: <Epic Title>

GAP 1: [Business Value Gap]
  Issue: <specific issue>
  Evidence: <what was found>
  Required: <what must be done>

GAP 2: [Test Integrity Gap]
  Issue: Mock found in integration test for <component>
  Location: tests/integration/test_api.py:45
  Required: Replace mock with real service call

GAP 3: [Skills Not Consulted]
  Issue: OAuth implementation does not match current best practices
  Evidence: Story bd-xxxx embedded context predates skill updates
  Required: Verify implementation against <skill-name> skill

VERDICT: GAPS_FOUND
ACTION: Sr. PM must create stories to address all gaps.
These gaps MUST be resolved before next milestone.
```

### Handling Gaps

When Anchor returns GAPS_FOUND:

1. **Orchestrator collects all gaps**
2. **Orchestrator spawns Sr. PM:**
   ```python
   @pivotal-sr-pm
   # Task: Create stories to address milestone gaps from Anchor review.
   #
   # Gaps from epic {epic.id}:
   # {gaps_list}
   #
   # Create targeted stories to fill these gaps.
   # These stories should be prioritized BEFORE any new milestone work.
   # Mark them with label 'gap-fix' for tracking.
   ```
3. **Gap stories are created in the backlog**
4. **Gap stories must be completed before next milestone begins**
5. **Gaps are NOT blocking execution** - work can continue on non-milestone epics

### What Anchor Looks For (Test Inspection)

**Test files to inspect:**
```bash
# Find integration test files
fd -e py -e ts -e js . tests/integration/ test/integration/

# Grep for mock usage (should NOT exist in integration tests)
rg "mock|Mock|patch|stub|Stub|jest.fn|vi.fn|sinon" tests/integration/

# Check for skip decorators (should NOT exist without reason)
rg "@skip|@pytest.mark.skip|.skip\(" tests/
```

**Red flags in test code:**
- `mock.patch` in integration tests
- `jest.mock` in E2E tests
- `MagicMock` anywhere outside unit tests
- Comments like "# TODO: add real test"
- Empty test bodies
- Tests that only check "not None"
- Assertions that always pass

### Common Sense Beyond Specs

The Anchor applies judgment beyond literal requirements:

**Questions to ask:**
- "Would a real user be satisfied with this?"
- "Does this solve the problem, or just implement the solution?"
- "If I were the stakeholder, would I accept this?"
- "Are we building what they need, or what they asked for?"
- "Does this make the product better?"

**This is NOT scope creep.** It's validating that what was built actually works and serves its purpose. Specs can be followed precisely and still miss the point.

## External Repository Access

**When developers encounter bugs in other repos (owned libraries, dependencies), they have STRICT limitations:**

### Allowed Actions
- **READ files** - to understand behavior, diagnose issues, gather context
- **FILE BUGS** - create issues with full context for another agent to fix

### Prohibited Actions (NEVER)
- Write code in other repos
- Create commits in other repos
- Run tests in other repos
- Make any modifications

### When Story Depends on External Fix

If a story cannot proceed without a fix in another repo:

1. **File the bug** in the external repo with full context
2. **Block the story** with clear dependency explanation
3. **Wait** for the external fix to land

```bash
bd update <story-id> --status blocked --notes "BLOCKED: Depends on external fix.
External Bug: <repo>/<bug-id>
Blocker: <why story cannot proceed>
Resume When: External bug is fixed and merged."
```

**This surfaces true dependencies and priorities.** The story remains blocked until resolved.

## Milestones and Demos

**A milestone is new demoable functionality.** Not every epic is a milestone.

### Walking Skeleton First

Start with the **thinnest e2e slice** - simplest request flows through ALL layers with real integration (no mocks).

### Vertical Slices, Not Horizontal Layers

**WRONG:** Build ReasoningEngine (isolated) -> Build DecisionService (isolated) -> Integration missing

**RIGHT:** User can make simplest decision (all layers) -> Add complexity -> Extend working slice

### Demo = Real Execution

**No test fixtures, no mocks, no placeholders.** If you can't demo with real requests hitting real code, it's not done.

### Milestone Completion Summary (MANDATORY)

When a milestone epic is accepted, the orchestrator MUST output a **human-readable summary** of what was achieved. This summary:

- Is written for humans, not agents
- Explains what functionality now exists
- Describes what users can now do that they couldn't before
- Uses plain language, avoiding technical jargon where possible
- Provides context even if execution continues to the next epic

**Format:**
```
=== MILESTONE COMPLETE: <Epic Title> ===

What was built:
<Plain language description of the new functionality>

What users can now do:
- <Capability 1>
- <Capability 2>
- ...

Key technical achievements:
- <Achievement 1>
- <Achievement 2>

Status: Continuing to next epic / Awaiting feedback / Complete
==========================================
```

**Purpose:** The process runs unattended, but the user should be able to read these summaries asynchronously and understand exactly what has been accomplished. Each milestone is a checkpoint where the user gains visibility into progress.

### Milestone Feedback Loop

Milestones are natural points for user feedback in the iterative process. While execution continues unattended:

1. **User can provide async feedback** at any time by adding comments or notes
2. **At each milestone**, Sr. PM should assess any accumulated user input before the next epic begins
3. **Early milestones are especially valuable** for course correction - feedback here prevents larger rework later

**Sr. PM responsibilities at milestones:**
- Review any user feedback provided since last milestone
- Assess if feedback requires backlog adjustments
- Incorporate relevant feedback into upcoming stories
- Flag significant scope changes to user (but don't block on response)

**The process remains unattended** - Sr. PM assesses and incorporates feedback without waiting for user response. If feedback requires decisions that cannot be made autonomously, the story is blocked with clear explanation.

## Personas Summary

| Phase | Role | Key Responsibility |
|-------|------|-------------------|
| D&F | Facilitator | Orchestrates D&F, extracts outcomes |
| D&F | BA | BUSINESS.md, business outcomes |
| D&F | Designer | DESIGN.md, all user needs, DX |
| D&F | Architect | ARCHITECTURE.md, security/compliance |
| D&F | Sr PM | Creates backlog with embedded context, incorporates learnings |
| D&F | Anchor | Reviews backlog for gaps until satisfied |
| Exec | Orchestrator | NEVER writes code. Spawns agents, manages epic lifecycle |
| Exec | Developer | Ephemeral. Implements story, records proof, marks delivered |
| Exec | PM-Acceptor | Ephemeral. Evidence-based review, accepts/rejects, captures test gap learnings |
| Exec | Retro | Ephemeral. After milestone completion, extracts learnings, writes to .learnings/ |
| Exec | Anchor (Milestone) | Ephemeral. After retro, validates real delivery - inspects tests, verifies skills consulted, applies common sense |

## See Something, Say Something (MANDATORY)

**All operational agents MUST report abnormalities they observe, even if unrelated to their current task.**

This is not optional. Issues buried are issues that compound. The codebase belongs to everyone.

### The Principle

When any agent (Developer, PM-Acceptor, Anchor, Retro) observes something abnormal, incorrect, or concerning during their work, they MUST report it - even if it has nothing to do with their assigned task.

**Examples of "something":**
- Broken tests in unrelated modules
- Security vulnerabilities in code they're reading
- Dead code or unused imports
- Inconsistent naming or patterns
- Missing error handling
- Hardcoded values that should be configurable
- Documentation that contradicts the code
- Race conditions or concurrency issues
- Performance problems (N+1 queries, etc.)
- Deprecated API usage

### How to Report

Agents report observations in their delivery/completion notes using a standardized section:

```
OBSERVATIONS (unrelated to this task):
- [ISSUE] <file:line>: <description of problem>
- [ISSUE] <component>: <description of problem>
- [CONCERN] <area>: <something that seems off but unclear>
```

**PM-Acceptor extracts these** during Phase 4.5 (Discovered Issues Extraction) and files them as bugs/tasks.

### Why This Matters

- **"Not my problem" is not acceptable.** The codebase is everyone's problem.
- **Buried issues compound.** Small problems become big problems.
- **Fresh eyes catch things.** Developers working in unfamiliar areas spot issues others miss.
- **Continuous improvement.** The backlog reflects true system state.

### Agent Responsibilities

| Agent | What to Watch For |
|-------|------------------|
| Developer | Code quality issues, bugs, security problems, dead code |
| PM-Acceptor | Test quality issues, code smells, missing coverage |
| Anchor | Backlog gaps, missing stories, architectural drift |
| Retro | Patterns across learnings, systemic issues |

**No agent is exempt.** If you see something, say something.

## Best Practices

- **Outcomes first** - technical details support outcomes
- **Challenge the user** - question assumptions, push back on unclear requirements
- **Sr PM embeds ALL context + testing requirements** - developers need nothing beyond the story
- **Orchestrator NEVER writes code** - spawns Developer agents
- **Developers MUST record proof** - PM uses evidence, not re-testing
- **Rejected stories prioritized first** - clear the queue before new work
- **Spikes for ambiguity** - don't guess, investigate
- **Capture test gap learnings** - when bugs slip through, PM documents WHY and outputs to user (non-blocking)
- **Other repos: read and file bugs only** - never modify external repos; block stories if dependent on external fixes
- **Anchor validates reality at milestones** - not just process compliance but actual delivery: no mocks in tests, skills consulted, common sense applied
- **Gap stories before next milestone** - any gaps found by Anchor must be resolved before next milestone can begin

## Config & Tooling

### Beads Config
`.beads/config.yaml` enforces: AC required, epic business value required, coverage command, integration test command.

### Paivot Config (Parallelization)
Config file controls agent parallelization:

```yaml
---
max_parallel_devs: 2   # Max Developer agents at once (default: 2)
max_parallel_pms: 1    # Max PM agents at once (default: 1)
---
```

Create/edit via `/piv-config` command or manually. Add to `.gitignore`.
