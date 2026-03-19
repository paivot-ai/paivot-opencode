---
name: piv-loop
description: Run unattended execution loop until blocked or all work is done
arguments: "[EPIC_ID] [--all] [--max-iterations|--max N]"
---

# piv-loop -- Unattended Execution Loop

Run the backlog forward one epic at a time without manual intervention. The loop
drains each epic fully (all stories accepted, merged, e2e verified) before rotating
to the next. Parallelization happens WITHIN the current epic, not across epics.

## Defaults and Settings

| Setting | Default | Override |
|---------|---------|----------|
| Epic selection | Auto (highest-priority with actionable work) | `--epic EPIC_ID` |
| Scope | Single epic at a time | `--all` (legacy, no containment) |
| Auto-rotate | On (rotate to next epic after completion gate) | Inherent to epic mode |
| Max iterations | 50 | `--max N` (0 = unlimited) |
| Concurrency | Within current epic only | Stack-dependent limits |

The dispatcher NEVER picks stories from outside the current epic. `pvg loop next --json`
enforces this structurally -- it only returns stories scoped to the active epic.

## Setup

If `$ARGUMENTS` is non-empty, run:
```bash
pvg loop setup $ARGUMENTS
```

If `$ARGUMENTS` is empty, run the bare command (auto-selects the highest-priority epic):
```bash
pvg loop setup
```

To target a specific epic: `pvg loop setup --epic EPIC_ID`
To run across all epics without containment (not recommended): `pvg loop setup --all`

Verify activation succeeded before continuing.

**Shell hygiene:** Do NOT append `2>&1` to nd or pvg commands. The shell tool already
captures stderr separately. Redirecting stderr causes duplicate error display.

All tracker operations below must use the shared live nd wrapper:

```bash
pvg nd <command>
```

## Iteration Protocol

Each iteration, run:

```bash
pvg loop next --json
```

This returns a JSON decision. Follow it:

| Decision | Action |
|----------|--------|
| `act` | Spawn the agent specified in `next` (developer or pm_acceptor) |
| `epic_complete` | Run the epic completion gate (e2e + Anchor + merge to main), then rotate |
| `epic_blocked` | All remaining work in the current epic is blocked. Escalate to user |
| `wait` | Agents are working in the current epic. Do nothing. Wait for completions |
| `rotate` | Epic is done and gate passed. Update loop state to the new epic in `next_epic` |
| `complete` | All epics drained. Allow exit |
| `blocked` | All remaining work globally is blocked (--all mode). Allow exit |

**`pvg loop next --json` is the SINGLE SOURCE OF TRUTH for dispatch decisions.**
Do NOT query nd directly with `pvg nd ready --json` or `pvg nd list --json` for choosing
what to work on next. Those queries are unscoped and will return stories from ALL epics,
breaking containment.

You MAY use nd directly for:
- Reading story content before spawning a developer (`pvg nd show STORY_ID`)
- Checking story labels (`pvg nd show STORY_ID --json`)
- Bug triage routing (DISCOVERED_BUG blocks)
- Epic auto-close checks after PM acceptance

When `decision=act`, spawn the returned role for the returned story:
- `pm_acceptor` for `queue=delivered`
- `developer` for `queue=rejected`
- `developer` for `queue=ready`

The returned `phase` field tells you whether a hard-tdd story should start in
`RED PHASE` or normal mode. Do not re-implement delivered/rejected/ready ordering
in prompt logic.

### Bug Triage (Overrides Iteration Protocol)

After any Developer or PM-Acceptor agent completes, scan its output for
`DISCOVERED_BUG:` blocks BEFORE running `pvg loop next --json`. If found,
collect ALL bug reports and spawn `@paivot-sr-pm` with:

```
BUG TRIAGE MODE. Create properly structured bugs for these discovered issues:
<paste all DISCOVERED_BUG blocks>
```

Wait for Sr. PM to finish before continuing. Bugs need epic placement and
dependency chains before other work can be prioritized correctly.

**Note:** When `bug_fast_track` is enabled (or story has `pm-creates-bugs` label),
PM-Acceptor creates bugs directly during review. Only bugs from Developer agents
or from PM-Acceptor in centralized mode (the default) appear as DISCOVERED_BUG blocks.

### After PM-Acceptor Acceptance

**IMMEDIATELY after acceptance**: merge the story branch to main (or epic branch
if using two-level branching). Complete the merge -- including conflict resolution
if needed -- before running `pvg loop next --json` again. An accepted story with
an unmerged branch is incomplete work.

## Epic Flow

The loop drains one epic at a time:

1. **Start**: auto-selects the highest-priority epic with actionable work
2. **Execute**: all parallelization happens WITHIN the current epic
   (multiple developers on different stories, one PM reviewing)
3. **Complete**: when all stories are accepted and merged,
   `pvg loop next --json` returns `epic_complete`
4. **Gate**: run the epic completion gate (e2e tests + Anchor milestone review + merge to main)
5. **Rotate**: `pvg loop next --json` returns `rotate` with `next_epic` -- update state and continue

Epic completion is a GATE, not a passthrough. The full gate (e2e, Anchor, merge to main)
MUST finish before rotation. There is no cherry-picking across epics.

## Concurrency Limits (HARD RULE)

All concurrency is WITHIN the current epic.

Limits are stack-dependent. Detect from project files (Cargo.toml, *.xcodeproj,
*.csproj, wrangler.toml/wrangler.jsonc, pyproject.toml, package.json, etc.).

Heavy stacks (Rust, iOS/Swift, C#, CloudFlare Workers):
- Maximum 2 developer agents simultaneously
- Maximum 1 PM-Acceptor agent simultaneously
- Total active subagents (all types) must not exceed 3

Light stacks (Python, non-CF TypeScript/JavaScript):
- Maximum 4 developer agents simultaneously
- Maximum 2 PM-Acceptor agents simultaneously
- Total active subagents (all types) must not exceed 6

When a project mixes stacks, use the most restrictive limit.
Wait for an agent to finish before spawning another if at the limit.

These limits prevent context and machine resource exhaustion.

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
- Query nd globally for dispatch decisions (use `pvg loop next --json` instead)

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
| Sr. PM (bug triage) | `@paivot-sr-pm` | DISCOVERED_BUG blocks found in agent output |
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

## Story Merge (After PM Approves)

After PM-Acceptor accepts a story, merge it immediately:

```bash
pvg story merge <STORY-ID>
```

If a merge conflict occurs, spawn a developer to resolve it:

```
CONFLICT RESOLUTION MODE. Story STORY_ID is accepted but cannot merge.

Your task: rebase story/STORY_ID onto the latest target branch, resolving
all conflicts.

Steps:
1. git fetch origin
2. git checkout story/STORY_ID
3. git rebase origin/main  (or origin/epic/EPIC_ID if two-level branching)
4. Resolve conflicts in each file (keep functionality from both sides)
5. git rebase --continue after each resolution
6. Run tests to verify nothing is broken
7. git push --force-with-lease origin story/STORY_ID

Do NOT update nd -- the story is already accepted and closed.
Report: list of conflicting files, resolution decisions, test results.
```

After developer completes, retry `pvg story merge <STORY-ID>`. If retry still
fails, escalate to user.

**Merge order:** If multiple stories are waiting to merge, process them in
dependency order first, then priority order (P0 first). Use `pvg nd dep tree STORY_ID`
and `pvg nd show STORY_ID --json` to inspect dependencies; merge prerequisite
stories before dependents.

## Epic Completion (All Stories Merged)

When `pvg loop next --json` returns `epic_complete`, the epic enters a three-step
completion gate before merging to main. All three steps are structural -- no step
may be skipped.

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

**After merge to main**: run `pvg loop next --json` again. It will return
either `rotate` (with the next epic) or `complete` (all done).

## Termination

The loop drains one epic at a time. Termination is evaluated by `pvg loop next --json`
decisions:

| Condition | Action |
|-----------|--------|
| No actionable epics remain (`complete`) | Allow exit |
| Current epic blocked, no other epics (`epic_blocked`) | Escalate to user, allow exit |
| All remaining work globally blocked (`blocked`, --all mode) | Allow exit |
| Max iterations reached | Allow exit |
| Too many consecutive waits (3) | Allow exit |
| Current epic has actionable work (`act`) | Continue |
| Current epic complete, gate pending (`epic_complete`) | Run gate, continue |
| Current epic complete, next epic exists (`rotate`) | Update state, continue |

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
