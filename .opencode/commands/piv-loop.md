---
name: piv-loop
description: Run unattended execution loop until complete or blocked
arguments: "[EPIC_ID] [--all] [--max-iterations|--max N]"
---

# piv-loop -- Unattended Execution Loop

Run the backlog to completion without manual intervention. Spawns developer and PM agents
in priority order until all work is done, blocked, or max iterations reached.

## Setup

**IMPORTANT:** `pvg loop setup` REQUIRES either `--all` or `--epic EPIC_ID`. Running it
without these flags will fail. Do NOT attempt the bare command.

If `$ARGUMENTS` is non-empty, run:
```bash
pvg loop setup $ARGUMENTS
```

If `$ARGUMENTS` is empty, ask the user FIRST:
- "Run all ready work (`--all`) or target a specific epic (provide the EPIC_ID)?"
- "Max iterations? (default: 50, 0 for unlimited)"

Then run `pvg loop setup` with the user's chosen flags. Verify activation succeeded
before continuing.

**Shell hygiene:** Do NOT append `2>&1` to nd or pvg commands. The shell tool already
captures stderr separately. Redirecting stderr causes duplicate error display.

## Priority Order

Each iteration, pick work in this order:

0. **Sr. PM for bug triage** (highest priority -- discovered bugs need structure)
   After any Developer or PM-Acceptor agent completes, scan its output for
   `DISCOVERED_BUG:` blocks. If found, collect ALL bug reports and spawn
   `@paivot-sr-pm` with:
   ```
   BUG TRIAGE MODE. Create properly structured bugs for these discovered issues:
   <paste all DISCOVERED_BUG blocks>
   ```
   Wait for Sr. PM to finish before continuing.

1. **PM-Acceptor for delivered stories** (unblock the pipeline)
   ```bash
   nd list --status delivered --json
   ```
   For each: spawn `@paivot-pm` agent to review and accept/reject.
   **The PM-Acceptor closes the story itself** (`nd close --reason`). Do NOT
   re-close stories after the PM-Acceptor finishes.
   **After each acceptance**: the PM-Acceptor runs epic auto-close.

2. **Developer for rejected stories** (fix before starting new work)
   ```bash
   nd list --status rejected --json
   ```
   For each: spawn `@paivot-developer` agent to address rejection notes.

3. **Developer for ready stories** (new work)
   ```bash
   nd ready --sort priority --json
   ```
   Pick the highest-priority item (P0 first, then P1, etc.).
   For each: spawn `@paivot-developer` agent to implement.
   **An empty result from this query is the ONLY signal that work is done.**

**nd filter cheat sheet**:
- Priority: `--priority 0` (not `--label P0`)
- Status: `--status delivered`, `--status rejected`
- Labels: `--label hard-tdd`, `--label tdd-red`, `--label tdd-green`
- Type: `--type bug`, `--type task`, `--type epic`
- Parent: `--parent <epic-id>`

## Concurrency Limits (HARD RULE)

Limits are stack-dependent. Detect from project files.

Heavy stacks (Rust, iOS/Swift, C#, CloudFlare Workers):
- Maximum 2 developer agents simultaneously
- Maximum 1 PM-Acceptor agent simultaneously
- Total active subagents must not exceed 3

Light stacks (Python, non-CF TypeScript/JavaScript):
- Maximum 4 developer agents simultaneously
- Maximum 2 PM-Acceptor agents simultaneously
- Total active subagents must not exceed 6

When a project mixes stacks, use the most restrictive limit.

## Dispatcher Rules

You are a dispatcher. You coordinate agents. You NEVER:
- Write source code or tests yourself
- Fix errors or bugs yourself
- Modify story files yourself
- Make architectural decisions yourself
- Skip agents to "save time"
- Resolve merge conflicts yourself (spawn a developer)
- Edit source files for any reason
- Re-close stories that the PM-Acceptor already closed

If an agent fails, re-spawn it with corrective guidance. Do not do its work.

## Infrastructure Context (MANDATORY before first developer spawn)

Before spawning the first developer agent in a session, discover what infrastructure
is available locally and include connection details in ALL developer agent prompts.

**Discovery protocol:**
1. `docker ps --format '{{.Names}} {{.Ports}}'` -- running containers
2. Check for docker-compose files, .env files with connection strings
3. Check project README/docs for infrastructure requirements

**Include in developer prompts:**
- List of running services with host:port
- Database connection details
- Required env vars with values (or instructions to obtain them)
- Explicit instruction: "Infrastructure is running. Do NOT gate tests behind env
  vars. Run integration tests directly against these services."

Without this context, developers will reasonably gate tests behind env vars --
creating dormant tests that satisfy no testing gate.

## Agent Types

| Role | Agent | When |
|------|-------|------|
| Sr. PM (bug triage) | `@paivot-sr-pm` | DISCOVERED_BUG blocks found |
| PM-Acceptor | `@paivot-pm` | Stories with `delivered` status |
| Developer | `@paivot-developer` | Ready or rejected stories |

## Developer Spawning: Normal vs Hard-TDD

Hard-TDD is **opt-in per story**. Before spawning a developer, check for the `hard-tdd` label:

```bash
nd show <id> --json | grep -q '"hard-tdd"'
```

**If `hard-tdd` label is ABSENT** (default): spawn ONE developer in normal mode.

**If `hard-tdd` label is PRESENT**: run the two-phase flow:
1. RED phase: spawn developer with "RED PHASE" in the prompt (tests only)
2. PM-Acceptor reviews tests
3. GREEN phase: spawn developer with "GREEN PHASE" in the prompt (implementation only)
4. PM-Acceptor reviews implementation

## Termination Conditions

The loop runs across the ENTIRE backlog, not a single epic.

Check termination after each iteration by querying nd directly:

```bash
# Check if any work remains
DELIVERED=$(nd list --status delivered --json | jq 'length')
REJECTED=$(nd list --status rejected --json | jq 'length')
READY=$(nd ready --json | jq 'length')
IN_PROGRESS=$(nd list --status in_progress --json | jq 'length')

if [ "$DELIVERED" -eq 0 ] && [ "$REJECTED" -eq 0 ] && [ "$READY" -eq 0 ] && [ "$IN_PROGRESS" -eq 0 ]; then
    echo "LOOP COMPLETE: All work finished"
    pvg loop cancel
    exit 0
fi

if [ "$DELIVERED" -eq 0 ] && [ "$REJECTED" -eq 0 ] && [ "$READY" -eq 0 ] && [ "$IN_PROGRESS" -gt 0 ]; then
    echo "LOOP WAITING: Only in-progress work remains (agents running)"
fi
```

| Condition | Action |
|-----------|--------|
| Entire backlog complete | Exit loop |
| All remaining work blocked | Exit loop |
| Max iterations reached | Exit loop |
| Actionable work exists | Continue loop |

Epic completion is NOT a termination event. The loop moves to the next epic.

## Cancellation

To cancel: `/piv-cancel-loop` or `pvg loop cancel`

## Post-Compaction Recovery

After context compaction, run recovery:

```bash
pvg loop recover
```

This cleans orphan worktrees, resets orphaned in-progress stories, and outputs a recovery summary.
