---
name: piv-loop
description: Run unattended until complete or blocked
arguments: "[EPIC_ID] [--all] [--max-iterations N]"
---

# Paivot Execution Loop

You are starting an unattended execution loop. This loop will continue automatically until all work is complete or blocked.

## Setup

First, run the setup script to activate the loop:

```bash
piv loop setup $ARGUMENTS
```

Enable FSM enforcement for this loop:

```bash
if command -v piv >/dev/null 2>&1; then
    piv config set enforcement_enabled true
fi
```

## How It Works

1. **Stop hook intercepts exit** - When you try to exit, the hook checks beads state
2. **Work remains = continue** - If stories are ready, delivered, or in-progress, loop continues
3. **Complete or blocked = exit** - Loop ends when work is done or all blocked

## Parallelization Configuration

Check for `.opencode/paivot.local.md` to get parallelization limits:

```bash
cat .opencode/paivot.local.md 2>/dev/null || echo "Using defaults: max_parallel_devs=2, max_parallel_pms=1"
```

**Default limits** (when no config file exists):
- `max_parallel_devs`: 2 - Maximum Developer agents at once
- `max_parallel_pms`: 1 - Maximum PM agents at once

To change limits, create/edit `.opencode/paivot.local.md` or run `/piv-config`.

## Execution Rules

You are the orchestrator. Follow these rules strictly:

### Priority Order (Each Iteration)
1. **PM-Acceptor for delivered stories** - Review first
2. **Developer for rejected stories** - Fix before new work
3. **Developer for ready stories** - Implement new stories

### Spawning Pattern (Respecting Limits)

Read config (defaults: max_devs=2, max_pms=1) from `.opencode/paivot.local.md`.

Check for delivered work first:
```bash
bd list --status in_progress --label delivered --json
```

Spawn up to `max_parallel_pms` PM agents:
```
Invoke the agent:
@pivotal-pm "Review delivered story bd-xxx. Evidence-based review."
```

Then check for ready work:
```bash
bd ready --json
```

Spawn up to `max_parallel_devs` Developer agents (rejected stories first):
```
Invoke the agent:
@pivotal-developer "Implement story bd-xxx. ALL commits go to beads-sync. Record proof."
```

Remaining work will be handled in next iteration.

### Critical Rules

- **NEVER write code yourself** - Always spawn Developer agents
- **Respect parallelization limits** - Check `.opencode/paivot.local.md` (defaults: 2 devs, 1 pm)
- **Remaining work handled next iteration** - Don't exceed limits; loop continues
- **NARROW test scope** - Story-specific tests, not full suite (unless milestone)
- **Log progress** - Update story notes so user can review later

### After Agent Returns

When a Developer or PM agent finishes and returns results:
- **IGNORE compilation errors, test failures, or diagnostic warnings** - you are a DISPATCHER, not a FIXER
- **Check if story was delivered** (`bd show <id>` - look for `delivered` label)
- **If delivered**: Spawn PM-Acceptor to review. PM decides if errors matter.
- **If PM rejects**: Spawn a NEW Developer. Never fix code yourself.
- **Your job**: Dispatch agents and manage the loop. Not fix code.

## Loop Termination

The loop automatically terminates when:

| Condition | Action |
|-----------|--------|
| All stories accepted | Exit with success message |
| All work blocked | Exit with list of blocked stories |
| Max iterations reached | Exit with progress report |
| `/piv-cancel-loop` invoked | Exit immediately |

## Monitoring (User Can Check)

```bash
# Check current iteration
grep '^iteration:' .opencode/piv-loop.local.md

# Check backlog state
bd stats --json

# View loop state file
cat .opencode/piv-loop.local.md
```

## Begin Execution

After setup completes, immediately start the dispatch loop:

1. Check `bd list --status in_progress --label delivered --json` for work needing PM review
2. Check `bd ready --json` for work needing implementation
3. Spawn appropriate agents
4. When agents complete, you'll naturally try to exit
5. The stop hook will either continue the loop or allow exit

**Start now.** Check for delivered stories first, then ready stories.
