---
name: piv-recover
description: Recover from crash and resume
---

# Paivot Recovery

You are recovering from a crash or inconsistent state. This command diagnoses issues, cleans up, and resumes backlog execution.

**CARDINAL RULE: The orchestrator NEVER runs tests or does implementation work. All code work is delegated to Developer agents. Running all tests takes forever and is unnecessary - beads shows exactly what was in progress.**

## Phase 1: Diagnostics

Run ALL of these checks in parallel to understand the current state:

```bash
# Check beads database health
bd doctor --deep

# Check for stories in progress (may be orphaned)
bd list --status in_progress --json

# Check for delivered stories awaiting review
bd list --status in_progress --label delivered --json

# Check for blocked stories
bd blocked --json

# Check git state for uncommitted changes
git status --porcelain

# Check overall project health
bd stats --json
```

## Phase 2: Analyze Recovery Needs

Based on diagnostics, identify:

### Stories Needing Attention

1. **In-Progress Without Delivered Label** - Developer was mid-work when crash occurred
   - Check if the work branch has uncommitted changes
   - Read `bd show <story-id>` to understand progress
   - Decision: spawn Developer to resume OR reset to open (if no work started)

2. **Delivered But Not Reviewed** - PM never got to review
   - These are ready for PM-Acceptor spawn
   - Verify proof notes exist (if not, may need re-delivery)

3. **Blocked Stories** - May have stale blockers
   - Check if blocking issues are now resolved
   - Unblock if appropriate

### Git/Beads State Issues

1. **Uncommitted Changes** - Code changes not committed
   - Stage and commit before proceeding
   - Use descriptive "recovery commit" message

2. **Beads Sync Issues** - Database out of sync
   - Run `bd sync` to force synchronization
   - For ephemeral branches: `bd sync --from-main`

3. **Stale Worktrees** - Orphaned git worktrees
   - List with `git worktree list`
   - Clean up any that don't correspond to active epics

## Phase 3: Recovery Actions

**CRITICAL: The orchestrator NEVER does implementation work directly. All code work is delegated to Developer agents.**

### 3.1 Sync Beads Database

```bash
bd sync --from-main
bd sync
```

### 3.2 Handle Uncommitted Changes

If git status shows uncommitted changes, commit them as recovery state (DO NOT run tests or attempt fixes yourself):

```bash
git add .
git commit -m "recovery: uncommitted changes from crashed session"
```

### 3.3 Triage In-Progress Stories

For each story that is `in_progress` but NOT `delivered`, read the story to understand what was happening:

```bash
bd show <story-id>
```

**Option A - Spawn Developer to Resume** (default for any partially complete work):
- Add recovery context to the story notes
- Spawn a Developer agent in Phase 5 to complete the work
- DO NOT run tests or attempt fixes yourself

```bash
bd update <story-id> --notes "RECOVERY: Resuming from crashed session. Check git log for recent changes."
```

**Option B - Reset to Open** (ONLY if beads show clearly indicates no work was started):
```bash
bd update <story-id> --status open --notes "RECOVERY: Reset to open after session crash. No meaningful progress was made."
```

### 3.4 Handle Delivered Stories

For stories with `delivered` label but not yet reviewed:
- Verify proof notes exist in the story
- If proof exists: proceed to PM-Acceptor spawn in Phase 5
- If no proof: remove delivered label and the Developer will need to re-run tests

```bash
# Check for proof
bd show <story-id>

# If no proof, remove delivered label (Developer will re-deliver)
bd label remove <story-id> delivered
bd update <story-id> --notes "RECOVERY: Removed delivered label - no proof of passing tests found. Developer will re-run tests."
```

## Phase 4: Report Recovery Status

Present to user:

```
RECOVERY SUMMARY
================

Beads Health:     [OK/ISSUES FOUND]
Git State:        [CLEAN/COMMITTED CHANGES]

Stories Recovered:
- Reset to open:      X stories
- Ready for review:   X stories (delivered with proof)
- Need re-delivery:   X stories (delivered without proof)
- Blocked:            X stories

Ready to Resume:  [YES/NO - with reason if no]
```

## Phase 5: Resume Backlog Execution

**IMPORTANT: DO NOT ask for confirmation. Proceed automatically.**

After recovery completes successfully, immediately continue with the execution loop. Do not pause to ask "Would you like me to continue?" - just continue.

### Priority Order (same as /piv-start)

1. **PM-Acceptor for delivered stories** - Clear the review queue first
2. **Developer for rejected stories** - Fix rejected work before new work
3. **Developer for ready stories** - Implement new stories

### Spawn PM-Acceptors for Delivered Stories

For each story with `delivered` label and valid proof:

```
Invoke the agent:
@pivotal-pm "Review delivered story bd-xxx. Use developer's proof for evidence-based review. Accept or reject with detailed notes."
```

### Spawn Developers for In-Progress or Ready Stories

After PM review queue is processed, spawn developers for in-progress recovery or ready work:

```
Invoke the agent for RECOVERY:
@pivotal-developer "RECOVERY: Resume story bd-xxx from crashed session. Check git log for recent changes. Run ONLY tests relevant to this story (not the full test suite). Complete implementation and deliver with proof of passing tests."

Invoke the agent for NEW work:
@pivotal-developer "Implement story bd-xxx. ALL commits go to beads-sync. Record proof of all passing tests in delivery notes."
```

## Parallelization Configuration

Check for `.opencode/paivot.local.md` to get parallelization limits when spawning agents:

```bash
cat .opencode/paivot.local.md 2>/dev/null || echo "Using defaults: max_parallel_devs=2, max_parallel_pms=1"
```

**Default limits**: `max_parallel_devs=2`, `max_parallel_pms=1`

## Rules

- **NEVER run tests or do implementation** - orchestrator only diagnoses and spawns agents
- **Use beads as the source of truth** - `bd show` tells you exactly what was in progress
- **Diagnose before acting** - understand the full state before making changes
- **Preserve work where possible** - don't reset stories that have meaningful progress
- **Evidence-based decisions** - check git logs and beads notes before triaging
- **Report clearly** - user should understand what was recovered and why
- **Respect parallelization limits** - check `.opencode/paivot.local.md` (defaults: 2 devs, 1 pm)
- **Remaining work handled next iteration** - don't exceed limits

## Common Recovery Scenarios

### Scenario: Agent Crashed Mid-Implementation

1. Check if current branch has uncommitted changes
2. Commit any uncommitted changes as recovery state
3. Read `bd show <story-id>` to understand what was in progress
4. **Spawn a Developer agent** to resume - the Developer will run tests and complete delivery
5. DO NOT run tests yourself or attempt fixes

### Scenario: Environment Crashed During PM Review

1. Delivered stories should still be marked delivered
2. Spawn PM-Acceptors to complete review
3. No code changes needed

### Scenario: Session Compaction Lost Context

1. Run `bd prime` to reload methodology context
2. Use `bd show <id>` to read story details
3. Story contains all embedded context - no external reading needed
4. **Spawn a Developer agent** to resume work on any in-progress stories
