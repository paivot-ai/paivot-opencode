---
name: piv-loop
description: Run unattended execution loop until blocked or all work is done
arguments: "[EPIC_ID] [--all] [--max-iterations|--max N]"
---

# piv-loop -- Unattended Execution Loop

Run the backlog forward without manual intervention until all dispatchable work is
done, the loop is blocked, or max iterations are reached. Spawns developer and
PM agents in priority order. Epics complete with a full verification gate
(e2e tests + Anchor milestone review) before merging to main.

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

All tracker operations below must use the shared live nd wrapper:

```bash
pvg nd <command>
```

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

1. **Ask `pvg` what should happen next**
   ```bash
   pvg loop next --json
   ```
   `pvg` returns one of:
   - `decision=act` with the selected story, role, queue, scope, and hard-tdd hint
   - `decision=wait` when only in-progress work remains
   - `decision=complete` when the backlog is done
   - `decision=blocked` when only blocked work remains
   - `decision=other` when only non-dispatcher workflow states remain

   When `decision=act`, spawn the returned role for the returned story:
   - `pm_acceptor` for `queue=delivered`
   - `developer` for `queue=rejected`
   - `developer` for `queue=ready`

   The returned `phase` field tells you whether a hard-tdd story should start in
   `RED PHASE` or normal mode. Do not re-implement delivered/rejected/ready ordering
   in prompt logic.

**nd filter cheat sheet**:
- Priority: `--priority 0` (not `--label P0`)
- Status: `--status in_progress`, `--status open`
- Labels: `--label delivered`, `--label rejected`, `--label hard-tdd`
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
| PM-Acceptor | `@paivot-pm` | Stories with `delivered` label |
| Developer | `@paivot-developer` | Ready or rejected stories |

## Developer Spawning: Normal vs Hard-TDD

Hard-TDD is **opt-in per story**. `pvg loop next --json` returns `hard_tdd` and `phase`
for the selected story.

**If `hard-tdd` label is ABSENT** (default): spawn ONE developer in normal mode.

**If `hard-tdd` label is PRESENT**: run the two-phase flow:
1. RED phase: spawn developer with "RED PHASE" in the prompt (tests only)
2. PM-Acceptor reviews tests
3. GREEN phase: spawn developer with "GREEN PHASE" in the prompt (implementation only)
4. PM-Acceptor reviews implementation

## Epic Completion (All Stories Merged)

When all stories in the epic have been approved and merged to the epic branch,
the epic enters a three-step completion gate before merging to main. All three
steps are structural -- no step may be skipped.

**Step 1: Epic Verification Gate (STRUCTURAL -- always on)**

Run the FULL test suite on the merged epic branch. This catches integration
failures that passed in isolation on individual story branches but break when
combined. **No epic is done without passing e2e tests. Period.**

```bash
git fetch origin
git checkout epic/EPIC_ID
git pull origin epic/EPIC_ID

# Run the project's full test suite (unit + integration + e2e)
# Use the project's standard test command (make test, pytest, go test ./..., etc.)
```

**After running the test suite, verify e2e tests exist and ran:**

```bash
pvg verify --check-e2e
```

If `pvg verify --check-e2e` reports zero e2e test files, the gate FAILS --
even if all other tests passed. "0 e2e failures" with 0 e2e tests is not
passing, it is missing. Spawn a developer to write the e2e tests before
proceeding.

Every test must pass -- unit, integration, AND e2e. If any test fails:

1. Spawn `@paivot-developer` with:
   ```
   EPIC VERIFICATION FIX. Tests fail on the merged epic/EPIC_ID branch after
   all stories were integrated. Your task: fix the failing tests on the epic
   branch directly. This is NOT a story -- do not create nd issues. Run the
   full test suite after fixing and report results.

   Failing tests: <paste test output>
   Infrastructure: <paste connection details>
   ```
2. After the developer fix, re-run the full test suite.
3. If tests still fail after 2 developer attempts, escalate to user.

Do NOT skip this gate. Do NOT proceed to Step 2 with failing tests.

**Step 2: Anchor Milestone Review**

Spawn `@paivot-anchor` in milestone review mode:

```
MILESTONE REVIEW for epic EPIC_ID.

Validate that the completed epic delivered real value:
- Inspect tests for mocks in integration/e2e tests (forbidden)
- Verify skills were consulted where stories required them
- Check that boundary maps are satisfied (PRODUCES/CONSUMES)
- Validate hard-TDD two-commit pattern where applicable

Epic branch: epic/EPIC_ID
```

If the Anchor returns GAPS_FOUND, address the gaps (spawn developer to fix,
or escalate to user) before proceeding. Do NOT merge to main with open gaps.

**Step 3: Merge to Main**

Check the project workflow setting:

```bash
pvg settings workflow.solo_dev
```

**If `workflow.solo_dev=true`** (default -- solo developer, no PRs):

```bash
git checkout main
git pull origin main
git merge --no-ff epic/EPIC_ID -m "merge(main): complete EPIC_ID"
git push origin main
git branch -D epic/EPIC_ID
git push origin --delete epic/EPIC_ID
```

Then clean up all story branches for this epic:

```bash
for branch in $(git branch -r --list "origin/story/*" | sed 's|origin/||'); do
  git push origin --delete "$branch" 2>/dev/null || true
done
for branch in $(git branch --list "story/*"); do
  git branch -D "$branch" 2>/dev/null || true
done
```

**If `workflow.solo_dev=false`** (team workflow, PRs required):

```bash
git fetch origin
git checkout epic/EPIC_ID
git pull origin epic/EPIC_ID
gh pr create --base main --head "epic/EPIC_ID" \
  --title "merge(main): complete EPIC_ID" \
  --body "All stories accepted. Full test suite passing. Anchor review: VALIDATED."
```

If your environment provides PR automation, use it and continue unattended.
Otherwise stop after the PR is created and ask the user to complete or
approve the merge. Branch cleanup happens after the PR is merged.

## Termination Conditions

The loop runs across the ENTIRE backlog, not a single epic.

Check termination after each iteration by querying `pvg loop next --json`:

```bash
STEP=$(pvg loop next --json)
DECISION=$(printf '%s' "$STEP" | jq -r '.decision')

case "$DECISION" in
  complete)
    echo "LOOP COMPLETE: All work finished"
    pvg loop cancel
    ;;
  blocked)
    echo "LOOP BLOCKED: Only blocked work remains"
    pvg loop cancel
    ;;
  wait)
    echo "LOOP WAITING: Only in-progress work remains"
    ;;
esac
```

| Condition | Action |
|-----------|--------|
| Entire backlog complete | Exit loop |
| All remaining work blocked | Exit loop |
| Max iterations reached | Exit loop |
| Actionable work exists | Continue loop |

Epic completion is NOT a termination event. The loop moves to the next epic.

### Live Demo (before session exit)

Every session must produce demonstrable progress. Before the loop exits:

1. Identify what was delivered (accepted stories, completed epics, merged to main)
2. If anything was merged to main: run the project's demo, smoke test, or e2e suite
   on main and report results to the user
3. If nothing reached main: explain what blocked progress and what the user should
   do next

A session that cannot show working software at the end should be treated as a
signal that something is wrong with the backlog, the infrastructure, or the
test suite -- not as normal.

## Cancellation

To cancel: `/piv-cancel-loop` or `pvg loop cancel`

## Post-Compaction Recovery

After context compaction, run recovery:

```bash
pvg loop recover
```

This cleans orphan worktrees, resets orphaned in-progress stories, and outputs a recovery summary.
