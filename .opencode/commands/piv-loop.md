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

Verify activation succeeded before continuing. `pvg loop setup` also runs a
best-effort full `nd sync` (snapshot + fetch + field-aware merge + push of the
nd-native `nd/backlog` branch) so the loop starts from the latest shared
backlog. A sync failure is a WARN, never fatal -- offline and remote-less
repos still loop.

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

This returns a JSON decision. On actions, `priority` is the STORY's nd
priority (0 = P0); queue precedence is the `queue` field (delivered >
rejected > ready). Follow it:

| Decision | Action |
|----------|--------|
| `act` | Spawn the agent specified in `next` (developer or pm_acceptor). If the action carries `resume_agent`, resumption REPLACES the fresh spawn -- deliver the payload to the recorded agent per Semi-Persistent Story Agents below |
| `epic_complete` | Run the epic completion gate (e2e + Anchor + merge to main), then call `pvg loop rotate <next_epic>` and continue |
| `epic_blocked` | All remaining work in the current epic is blocked. Escalate to user |
| `wait` | Agents are working in the current epic. Do nothing. Wait for completions |
| `complete` | All epics drained. Allow exit |
| `blocked` | All remaining work globally is blocked (--all mode). Allow exit |
| `other` | Miscellaneous action surfaced in --all mode. Follow the action payload |
| `no_active_loop` | No loop is active. Run `pvg loop setup` before iterating |
| `stalled` | The same in_progress story set was observed for 3 consecutive wait evaluations. The payload lists the story ids and worktrees. Run `pvg loop recover`, then re-spawn each affected story or release it (`pvg story release <id>`) |
| `escalate` | A story hit the rejection cap (3 PM rejections). Surface it to the user with the rejection history and wait for direction. NEVER override the PM |

**`pvg loop next --json` is the SINGLE SOURCE OF TRUTH for dispatch decisions.**
Do NOT query the tracker directly with `pvg issues ready --json` or `pvg issues list --json`
for choosing what to work on next. Those queries are unscoped and will return stories from
ALL epics, breaking containment.

### Wave Dispatch (multiple ready stories)

When the current epic has multiple ready stories and the concurrency limit allows
k more developers, request a wave instead of looping one action at a time:

```bash
pvg loop next --json --n k
```

This returns up to k distinct actions in an `actions` array (at most one
pm_review per wave, then developers from the rejected/ready queues). The `next`
field still carries the first action. Spawn one developer per entry in
`actions[]` -- each gets its own story branch and dispatcher-managed worktree
exactly as described under Story Branch Setup. The single-source-of-truth rule
is unchanged: the wave comes from `pvg loop next`, never from unscoped nd queries.

Entries may also carry `resume_agent` and `resume_count`. Handle each such
entry per Semi-Persistent Story Agents below: resumption replaces the fresh
spawn for that entry, and a resumed agent counts toward the wave size and the
concurrency limits exactly like a spawned one.

You MAY use the issues CLI directly for:
- Reading story content before spawning a developer (`pvg issues show STORY_ID`)
- Checking story labels (`pvg issues show STORY_ID --json`)
- Bug triage routing (DISCOVERED_BUG blocks)
- Epic auto-close checks after PM acceptance

### Semi-Persistent Story Agents

Developer and PM conversations are reusable within a session. Instead of
paying a fresh spawn for every rework or re-review round, record each agent's
session handle at completion time and resume the same conversation when the
loop asks for it. OpenCode's native mechanism is the task tool's `task_id`
parameter: passing a recorded session id resumes that child conversation.

**Record on completion.** Task results render as `<task id="ses_XXXX" ...>`.
Immediately after a developer or PM task completes for story STORY_ID, record
that session id:

```bash
pvg loop agent set STORY_ID developer <ses-id>   # after a developer completes
pvg loop agent set STORY_ID pm <ses-id>          # after a PM completes
```

This applies to EVERY run of these roles -- first spawn, re-spawn after
failure, fresh-spawn fallback -- so the recorded handle always points at the
most recent conversation. pvg owns the resume counters and the 2-resume cap
per story+role.

**Resume on action.** `pvg loop next` actions may carry `resume_agent` (a
recorded handle) and `resume_count` on developer-rework and pm-review
actions. pvg emits them only when a handle is recorded, fewer than 2 resumes
have occurred for that story+role, and the `loop.agent_resume` setting
(default true) is enabled. When an action carries `resume_agent`:

1. Verify the story worktree still exists on disk.
2. Invoke the task tool with `subagent_type: paivot-developer` (or
   `paivot-pm`) AND `task_id: <handle>`. The message body is the
   rework/review payload (for developer rework: the PM rejection's
   EXPECTED/DELIVERED/GAP/FIX content).
3. **RESUME_MISS guard (REQUIRED).** OpenCode falls back to a FRESH child
   SILENTLY when the `task_id` is stale -- there is no error to catch. Every
   resume message MUST therefore begin with: "If you do not have prior
   context for story <STORY_ID> in this conversation, reply RESUME_MISS and
   stop." A RESUME_MISS reply means the resume did not happen.
4. On RESUME_MISS, any task error, or a missing worktree: run
   `pvg loop agent clear STORY_ID <role>`, fall back to the normal fresh
   spawn with the FULL context-injected brief (Context Injection Protocol),
   then `pvg loop agent set` the new handle. Also take this path when the
   agent's last delivery contained a CONTEXT_BUDGET note.

Fresh spawn is ALWAYS the safe fallback; resume is an optimization, never a
requirement. The current always-fresh behavior is the floor.

**Clear on accept.** After a story is accepted and merged, clear both roles:

```bash
pvg loop agent clear STORY_ID
```

**Handles are session-scoped -- but do not rely on that here.** OpenCode
child sessions persist on disk, and pvg's session-change invalidation may
not fire under OpenCode. The RESUME_MISS guard plus the failure ladder above
are the actual guarantee; `pvg loop recover` clears recorded handles.

**Why resume.** A resumed agent keeps its FULL conversation: rework costs a
fraction of a fresh spawn, the developer remembers its derivations and can
refute erroneous rejection claims instead of blindly re-implementing, and
LEARNINGS accumulate richer across rounds. The resumed agent's SHELL STATE
IS FRESH -- cwd and env vars reset -- which is why its first action is to cd
back into its worktree (this port already mandates a `cd` prefix on every
command). Transcripts grow with each round, hence the 2-resume cap.

**Model note.** A resumed child continues under the CURRENT top-level
`model` from `opencode.json` -- there is nothing per-agent to carry over. A
mid-loop model switch degrades prompt caching but not correctness; the
single-model design is unchanged.

**Worktree retention.** The story worktree is the resume anchor: while
`loop.agent_resume` is enabled (the default), do NOT remove the dev worktree
at delivery. It persists across rejection rounds until the story is accepted
and merged (or recovery removes it, which simply forces the fresh-spawn
fallback). PM review is unaffected: it stays on its no-worktree diff path
(`git diff`/`git show` against the story branch), which never needs the
branch checked out. If the dev worktree was removed anyway, re-create it at
the IDENTICAL path before resuming the developer -- or clear the handle and
spawn fresh.

### nd and vlt Usage

For nd CLI reference (commands, flags, dependencies, priorities), consult the nd skill documentation.

Do NOT guess nd flags or command syntax. Read the skill first. Common
mistakes prevented by reading it:
- Priority uses the P-prefixed form: `pvg issues create --priority P0` (nd
  accepts P0-P4 natively)
- Dependencies use `pvg nd dep add/rm`, not flags on `pvg issues update`

Do NOT run `nd upgrade` -- it is guard-blocked inside Paivot repos. `pvg update`
is the only toolchain convergence path (the channel manifest pins nd, machinery,
vlt, modelith, and pvg together).

Use `pvg nd` (not bare `nd`) for all live tracker operations.

**NEVER read `.vault/issues/` files directly** -- always use nd/pvg nd commands.

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

**Durability is automatic.** The Sr. PM writes new bugs (or stories) to the
live nd vault, which is NOT part of git history -- but every nd mutation
auto-snapshots locally to the `nd/backlog` git branch, so mid-epic creations
are durable the moment they land. No manual export or commit step is needed
here. The dispatcher's owned sync points are `pvg loop setup` (best-effort at
activation: failure is a WARN, never fatal), after each accepted story merge,
and at loop end -- each runs a full `nd sync` (snapshot + fetch + field-aware
merge + push of `nd/backlog`). Never copy files out of the live vault by
hand -- always go through `pvg nd sync`.

**Note:** When `bug_fast_track` is enabled (or story has `pm-creates-bugs` label),
PM-Acceptor creates bugs directly during review. Only bugs from Developer agents
or from PM-Acceptor in centralized mode (the default) appear as DISCOVERED_BUG blocks.

### After PM-Acceptor Acceptance

**IMMEDIATELY after acceptance**: merge the story branch to the epic branch.
Complete the merge -- including conflict resolution if needed -- before running
`pvg loop next --json` again. An accepted story with an unmerged branch is
incomplete work.

## Epic Flow

The loop drains one epic at a time:

1. **Start**: auto-selects the highest-priority epic with actionable work
2. **Execute**: all parallelization happens WITHIN the current epic
   (multiple developers on different stories, one PM reviewing)
3. **Complete**: when all stories are accepted and merged to the epic branch,
   `pvg loop next --json` returns `epic_complete`
4. **Gate**: run the epic completion gate (e2e tests + Anchor milestone review + merge to main)
5. **Retro**: spawn `@paivot-retro` to extract learnings before rotating
6. **Rotate**: call `pvg loop rotate <next_epic>` to transition loop state, then continue iterating

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
- Override, re-interpret, or bypass PM rejections -- if the PM rejected, the story goes back to the developer with the rejection feedback. You do not get to decide the rejection was "on a technicality" or "procedural." PM decisions are final.
- Re-submit rejected stories for acceptance without developer rework -- the developer must address the rejection feedback and re-deliver
- Call `pvg loop cancel` -- only the user can cancel the loop. You do not get to decide when to stop based on "context exhaustion," "productivity," "session length," or any other self-assessed risk.
- Query nd globally for dispatch decisions (use `pvg loop next --json` instead)
- Continue or resume a FAILED developer agent -- clean up the worktree, clear
  its handle (`pvg loop agent clear`), and re-spawn fresh. (Loop-directed
  resume is different: a `resume_agent` action targets an agent whose
  delivery the PM rejected, not one that failed -- see Semi-Persistent Story
  Agents)
- Inspect agent worktree internals (cd into worktrees, run git log, read files there)

**Rejection cap:** after 3 PM rejections of the same story, `pvg loop next`
emits the `escalate` decision instead of another rework action. Surface the
story and its rejection history to the user and wait for direction. The PM's
verdicts stand -- the dispatcher NEVER overrides the PM.

If an agent fails, re-spawn it with corrective guidance. Do not do its work.

### When a Developer Agent Fails or Completes (Abandonment Detection)

An agent "completed" signal does NOT mean the work finished. An ephemeral
agent that backgrounds a long build (or otherwise ends its turn to "wait")
is silently disposed -- typically minutes in, with intact but uncommitted
work. On EVERY developer completion or failure:

1. Check for a terminal outcome: `delivered` label (`pvg nd show <STORY_ID>`),
   or an explicit report in the agent output (ALREADY_LANDED, DISCOVERED_BUG,
   CONTEXT_BUDGET note). NOT by inspecting worktree internals.
2. If delivered: record the agent's handle (`pvg loop agent set <STORY_ID>
   developer <ses-id>`), then proceed with PM review. With `loop.agent_resume`
   enabled (the default), KEEP the dev worktree -- it is the story's resume
   anchor across any rejection rounds (see Semi-Persistent Story Agents);
   it is removed at accept+merge or by recovery. Only when resume is
   disabled, remove it now: `cd $PROJECT_ROOT && pvg worktree remove
   .claude/worktrees/dev-<STORY_ID>`.
3. If NOT delivered but the story branch HAS new commits: spawn a
   deliver-only follow-up (verify + `pvg story deliver`) -- cheap on a warm
   build. Do not discard committed work.
4. If NOT delivered and NO new commits: the agent abandoned.
   `cd $PROJECT_ROOT && pvg worktree remove .claude/worktrees/dev-<STORY_ID>`,
   then `pvg loop agent clear <STORY_ID> developer` (a failed agent's
   conversation is as suspect as its workspace), re-spawn a fresh developer
   with explicit instructions: fully synchronous execution, explicit
   timeouts, COMMIT before any long verification. Record the new handle when
   it completes.
5. NEVER try to continue or resume a dead or failed agent. (Loop-directed
   resume of a healthy, delivered agent after a PM rejection is the
   sanctioned path -- see Semi-Persistent Story Agents.)

PM completions: verify the decision actually landed (`pvg nd show <id>` must
show closed+accepted, rejected, or red-approved) before acting on it.

The loop also detects stalls structurally: when the same in_progress story
set is observed for 3 consecutive wait evaluations, `pvg loop next` returns
the `stalled` decision with the story ids and worktrees in its payload. Run
`pvg loop recover`, then either re-spawn each affected story or release it
(`pvg story release <id>`). Recovered stories are released (claim cleared,
back to open) and unmerged story branches are preserved, not deleted --
committed work survives recovery.

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

## Context Injection Protocol (MANDATORY before developer spawn)

Before spawning ANY developer agent, the dispatcher MUST enrich the prompt with
concrete codebase context. Advisory instructions like "search for existing modules"
are unreliable -- subagents skip them. Instead, the dispatcher reads the codebase
and INJECTS the context directly into the developer prompt.

### Step 1: Parse the story's CONSUMES block
Read the story and extract all CONSUMES entries. Each entry names an upstream module.

### Step 2: Extract API signatures from consumed modules
For each consumed module/file, read it and extract:
- Module name and one-line summary
- All type specifications / signatures on public functions
- Key usage examples

Include as "CODEBASE CONTEXT" in the developer prompt.

### Step 3: Scan ACs for cross-cutting keywords

Scan the story's acceptance criteria for keywords that indicate cross-cutting
concern integration is needed:

| Keyword | Module to discover | What to inject |
|---------|-------------------|----------------|
| DLP, scan, credential, PII | Gateway DLP/security module | scan API + severity handling |
| rate limit, throttle | Gateway rate limiter | check API + config key pattern |
| config, configuration | Project config module | How to add runtime keys + defaults |
| audit, log, telemetry | Observability module | Event emission pattern |
| allowed_paths, security | Path validation module | validate_allowed pattern |

For each keyword found, grep the codebase for relevant modules. Read discovered
modules and inject their public APIs into the developer prompt.

### Step 4: Inject existing patterns from accepted stories
If the story follows a walking skeleton, read one accepted module as a TEMPLATE
and inject the first ~30 lines showing module structure and annotations.

The developer receives everything needed to implement WITHOUT searching the codebase.

## Agent Types

| Role | Agent | When |
|------|-------|------|
| Sr. PM (bug triage) | `@paivot-sr-pm` | DISCOVERED_BUG blocks found in agent output |
| PM-Acceptor | `@paivot-pm` | Stories with `delivered` label |
| Developer | `@paivot-developer` | Ready or rejected stories |
| Retro | `@paivot-retro` | After epic completion gate passes (before rotation) |
| Anchor | `@paivot-anchor` | Backlog review or milestone review during epic gate |

## Story Branch Setup

When a story is selected for development, the dispatcher creates the story branch
from the epic branch (two-level model: `main -> epic -> story`):

Branch creation is NON-SWITCHING (`git branch`, never `git checkout -b`):
the dispatcher's HEAD stays on main, and a checked-out story branch would
also block the `git worktree add` that follows. OpenCode has no PreToolUse
guard to catch a story checkout at the root -- the discipline is entirely
yours.

```bash
# Ensure epic branch exists (create if needed)
git fetch origin
if ! git rev-parse --verify origin/epic/EPIC_ID >/dev/null 2>&1; then
  git branch epic/EPIC_ID origin/main
  git push -u origin epic/EPIC_ID
fi

# Create story branch from epic (no HEAD switch)
git branch story/STORY_ID origin/epic/EPIC_ID
git push -u origin story/STORY_ID
```

Then CLAIM the story and create a worktree for the developer:
```bash
pvg story claim STORY_ID    # atomic nd claim; MANDATORY before spawning
git worktree add .claude/worktrees/dev-STORY_ID story/STORY_ID
```

**Claiming at dispatch is not optional.** `pvg story claim` is atomic: it
delegates to `nd claim`, which moves the story to in_progress and records
the claiming agent in one step. There is no race window -- if the claim
fails, another agent already holds the story: skip it and move on, do not
retry or force it. This applies to EVERY developer spawn, including each
entry of a wave. To hand a claimed story back to the ready queue (for
example, after abandoning a spawn), run `pvg story release STORY_ID` -- it
returns the story to open and clears the claim.

The developer prompt MUST include the worktree path, and MUST state: run
everything synchronously with explicit timeouts (never background a build
and end your turn -- an ephemeral agent is disposed, not re-invoked), commit
work to the story branch before long verification runs, prefix every shell
command with `cd <worktree-absolute-path> &&` (CWD does not reliably persist
between calls), and for docker-compose projects pin
`COMPOSE_PROJECT_NAME=dev-STORY_ID` so concurrent agents never share
containers or build volumes.

**CRITICAL: Never use auto-isolation that creates disconnected branches.**
Commits on orphan branches are lost on cleanup. Always create worktrees manually
on the story branch.

## Developer Spawning: Normal vs Hard-TDD

Hard-TDD is **opt-in per story**. `pvg loop next --json` returns `hard_tdd` and `phase`
for the selected story.

On machinery-managed repos (`design.machinery` applies), hard-TDD is the
DEFAULT for stories touching machine-owned components: the Sr PM applies the
`hard-tdd` label to them at backlog creation, and `pvg lint --backlog` gains
the deterministic `hard-tdd-oracle` check -- ERROR when a story cites oracle
stable ids without the `hard-tdd` label. The label remains the switch; only
who applies it changes.

**If `hard-tdd` label is ABSENT** (default): spawn ONE developer in normal mode.

**If `hard-tdd` label is PRESENT**: run the two-phase flow. The phase is
tracked in nd by the `red-approved` label and carried on every loop action
as `phase` ("red" or "green") -- trust the loop output, do not infer:

1. RED phase: `pvg loop next` returns `developer_new` with `"phase":"red"`.
   Spawn developer with "RED PHASE" in the prompt (tests only). Developer
   delivers via `pvg story deliver`.
2. RED review: the loop returns `pm_review` with `"phase":"red"`. The PM
   validates the tests are properly RED and approves with
   `pvg story approve-red STORY_ID` -- this removes `delivered`, adds
   `red-approved`, and returns the story to the ready queue. A RED story is
   NEVER closed or labeled `accepted`.
3. GREEN phase: the loop returns `developer_new` with `"phase":"green"`
   (same story, now labeled `red-approved`). Spawn developer with
   "GREEN PHASE" in the prompt (implementation only; RED test files untouched --
   new test files allowed, edits/deletes to RED files are not).
4. GREEN review: the loop returns `pm_review` with `"phase":"green"`.
   Standard acceptance applies (`pvg story accept`).

A rejected story keeps its `red-approved` label, so rework actions carry
the correct phase automatically.

**GREEN is ALWAYS a fresh spawn.** NEVER resume the RED developer's
conversation for the GREEN phase, even though its handle is recorded. The
RED-to-GREEN boundary is a deliberate context wall: the implementation must
be constrained by the committed tests, not by the RED author's intent. pvg
enforces this structurally -- GREEN dispatches as a new-developer action,
which never carries `resume_agent` -- and the GREEN completion overwrites
the recorded handle (`pvg loop agent set`). Resuming WITHIN a phase is fine:
a rejected RED delivery may resume the RED developer for RED rework, and a
rejected GREEN delivery may resume the GREEN developer.

## Story Merge (After PM Approves)

After PM-Acceptor accepts a story, merge it immediately. Pre-merge checks,
each as its own command:

1. `git worktree list` -- if any worktree still holds `story/<ID>`
   (including the retained dev worktree -- the resume anchor is no longer
   needed once the story is accepted), remove it with
   `pvg worktree remove <path>`; a held branch blocks deletion after merge.
2. `git status --porcelain` -- must be clean.

```bash
pvg story merge <STORY-ID>
```

After the merge completes, run `pvg nd sync` -- the accepted-story merge is
one of the dispatcher's owned sync points (it snapshots, fetches, merges,
and pushes the `nd/backlog` branch). Then clear the story's recorded agent
handles: `pvg loop agent clear <STORY-ID>` (both roles -- see Semi-Persistent
Story Agents).

For any MANUAL git merge (gates, recovery): never chain `git checkout` and
`git merge` with `;` -- if the checkout aborts (dirty tree), the merge still
runs on whatever branch HEAD is actually on, which can land a story directly
on main. Use separate commands or `&&` only.

If a merge conflict occurs, spawn a developer to resolve it:

```
CONFLICT RESOLUTION MODE. Story STORY_ID is accepted but cannot merge.

Your task: rebase story/STORY_ID onto the latest target branch, resolving
all conflicts.

Steps:
1. git fetch origin
2. git checkout story/STORY_ID
3. git rebase origin/epic/EPIC_ID
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
dependency order first, then priority order (P0 first) within each ready layer.
Do NOT use `parent` for merge ordering: `parent` is epic containment, not the
dependency graph. Use `pvg nd dep tree STORY_ID` (nd-specific) and `pvg issues show STORY_ID --json`
to inspect `blocked_by`, `blocks`, and `follows`; merge prerequisite stories
before dependents.

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
- Validate hard-TDD pattern where applicable: the `tdd-red` commit precedes the
  GREEN implementation, RED test files were not edited/deleted afterward (new test
  files are allowed), and the RED tests still pass exactly as authored
  (`pvg story verify-tdd --base <epic-branch>`)

Epic branch: epic/EPIC_ID
```

Anchor verdicts are prefixed for reliable parsing: milestone reviews return
`REVIEW_RESULT: VALIDATED` or `REVIEW_RESULT: GAPS_FOUND`; backlog reviews
return `REVIEW_RESULT: APPROVED` or `REVIEW_RESULT: REJECTED`. (The Sr-PM/
Anchor backlog review loop caps at 3 rounds; after that, escalate the
remaining findings to the user.)

If the Anchor returns `REVIEW_RESULT: GAPS_FOUND`, address the gaps (spawn
developer to fix, or escalate to user) before proceeding. Do NOT merge to
main with open gaps. Proceed only on `REVIEW_RESULT: VALIDATED`.

**Step 3: Merge to Main**

Check the project workflow setting:

```bash
pvg settings workflow.solo_dev
```

**If `workflow.solo_dev=true`** (default -- solo developer, no PRs):

```bash
# Safety: ensure we have the latest main
git checkout main
git pull origin main

# Merge with --no-ff to preserve epic history
git merge --no-ff epic/EPIC_ID -m "merge(main): complete EPIC_ID"
git push origin main

# Clean up epic branch (local + remote)
# ALWAYS use -D (force). -d will fail because the remote tracking ref
# origin/epic/EPIC_ID still exists even though the branch is merged to HEAD.
git push origin --delete epic/EPIC_ID
git branch -D epic/EPIC_ID
```

**After** branch cleanup succeeds, close the epic in nd. The label contract
requires the epic to be closed BEFORE the `accepted` label is added -- two
canonical steps, in this order:
```bash
pvg nd close EPIC_ID --reason="All stories accepted, gate passed"
pvg nd update EPIC_ID --add-label accepted
```

Do NOT run nd updates in parallel with branch deletes. If the branch delete
errors, parallel calls may be cancelled -- losing the nd update.

**Then sync the backlog branch.** The live nd vault lives under
git-common-dir and is NOT part of git history; durability is nd-native.
Every nd mutation auto-snapshots locally to the `nd/backlog` git branch, and
`pvg nd sync` delegates to `nd sync`: snapshot + fetch + field-aware merge +
push of that branch. Run it here, as at every accepted story merge and at
loop end:

```bash
pvg nd sync            # snapshot + fetch + merge + push of nd/backlog
pvg nd sync --status   # show local/remote position without syncing
pvg nd sync --no-push  # sync but skip the push
```

`--commit` remains as a deprecated alias for a plain sync; the old export to
`.vault/backlog-snapshot/` is retired. `pvg doctor` now runs an
nd-sync-status check instead of the old snapshot-drift check.

(`pvg nd restore` delegates to `nd sync --restore`: it rebuilds a wiped live
vault from the `nd/backlog` branch, with a legacy snapshot fallback.)
`.vault/knowledge/` is the ONLY tracked path under `.vault/`, and it is
committed only by you -- the dispatcher, on main, after retro. Agents never
stage anything under `.vault/`.

Then clean up all story branches for this epic:

```bash
# Delete remote story branches
for branch in $(git branch -r --list "origin/story/*" | sed 's|origin/||'); do
  git push origin --delete "$branch" 2>/dev/null || true
done

# Delete local story branches
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
  --body "All stories accepted. Full test suite passing. Anchor review: REVIEW_RESULT: VALIDATED."
```

If your environment provides PR automation, use it and continue unattended.
Otherwise stop after the PR is created and ask the user to complete or
approve the merge. Branch cleanup happens after the PR is merged.

**Step 4: Retro**

After merging to main, spawn `@paivot-retro` to extract learnings:

```
EPIC RETRO for epic EPIC_ID.

Extract LEARNINGS from all accepted stories in this epic. Analyze patterns
across developer delivery notes and PM review feedback. Distill actionable
insights and write them to the project vault (.vault/knowledge/).

Epic: EPIC_ID
```

The retro agent is ephemeral -- it runs, captures knowledge, and is disposed.
Do NOT skip this step. Do NOT rotate to the next epic before retro completes.

**After retro completes**, commit any new `.vault/knowledge/` files it produced
to main. Knowledge notes are tracked; runtime state under `.vault/` (issues,
locks) remains gitignored. Agents never commit `.vault/` files -- this commit
is the dispatcher's job, on main:

```bash
git add .vault/knowledge
git commit -m "chore(paivot): retro knowledge for EPIC_ID"
git push origin main
```

**After retro**: if `epic_complete` included a `next_epic`, run
`pvg loop rotate <next_epic>` to transition the loop state, then resume
with `pvg loop next --json`. If no `next_epic` was provided (last epic),
the completion gate is still MANDATORY -- run all four steps (e2e, Anchor,
merge to main, retro) before allowing exit. Nothing enforces this for you
in OpenCode (no stop hook): do NOT exit while the epic branch exists unmerged.

## Termination

The loop drains one epic at a time. Termination is evaluated by `pvg loop next --json`
decisions:

| Condition | Action |
|-----------|--------|
| No actionable epics remain AND epic branch merged | Allow exit, remove state |
| Current epic blocked, no other epics (`epic_blocked`) | Escalate to user, allow exit |
| All remaining work globally blocked (`blocked`, --all mode) | Allow exit |
| Max iterations reached | Allow exit, remove state |
| Too many consecutive waits (3) | Allow exit |
| Current epic has actionable work (`act`) | Continue |
| Current epic complete, next epic exists | Block exit, run completion gate, then `pvg loop rotate` and continue |
| Current epic complete, NO next epic (last epic) | Block exit, run completion gate, then allow exit |
| Epic branch exists but all stories closed | Block exit, run completion gate (prompt-level mandate -- OpenCode has no stop hook to catch you) |

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

## Worktree Lifecycle

### Naming Convention
| Role | Worktree path | Branch |
|------|---------------|--------|
| Developer | `.claude/worktrees/dev-<STORY_ID>` | `story/<STORY_ID>` |
| PM-Acceptor | `.claude/worktrees/pm-<STORY_ID>` | detached at `story/<STORY_ID>` (only if a worktree is used at all) |

The worktree is disposable; the story branch is the durable record. The dev
worktree doubles as the story's RESUME ANCHOR while `loop.agent_resume` is
enabled (see Semi-Persistent Story Agents).

### Flow
1. Dispatcher creates story branch
2. Dispatcher creates dev worktree on story branch
3. Developer works, commits, pushes on story branch
4. Developer marks delivered
5. Dispatcher records the developer handle (`pvg loop agent set`). With
   `loop.agent_resume` enabled (the default), KEEP the dev worktree -- it is
   the resume anchor across any rejection rounds; it is removed at
   accept+merge (step 8) or by recovery. Only when resume is disabled,
   remove it now: `cd $PROJECT_ROOT && pvg worktree remove .claude/worktrees/dev-<STORY_ID>`
6. PM reviews on its no-worktree diff path (`git diff
   origin/epic/<EPIC>...origin/story/<ID>`, `git show`) -- no checkout
   needed. If a PM worktree is used at all, it must check the story out
   DETACHED (`git checkout --detach story/<STORY_ID>`): the retained dev
   worktree holds the branch ref, and git locks the ref, not the commit
7. If a PM worktree was created, dispatcher removes it: `cd $PROJECT_ROOT && pvg worktree remove .claude/worktrees/pm-<STORY_ID>`
8. If accepted: remove the retained dev worktree (pre-merge checks), merge
   story to epic, delete story branch, then clear the recorded handles:
   `pvg loop agent clear <STORY_ID>`
9. If rejected: the loop emits a rework action. When it carries
   `resume_agent`, resume the recorded developer per Semi-Persistent Story
   Agents -- the PM rejection content is the message body, and the retained
   dev worktree is the resume anchor. Otherwise (no handle, resume cap
   reached, resume disabled, RESUME_MISS, or any resume failure) re-create
   the dev worktree at the IDENTICAL path if missing and re-spawn a fresh
   developer with the rejection feedback. (After the third rejection of the
   same story the loop emits `escalate` -- see Dispatcher Rules)

### Cleanup

**Always prefix removal with `cd $PROJECT_ROOT &&`:**
```bash
cd $PROJECT_ROOT && pvg worktree remove .claude/worktrees/<worktree-name>
```

`pvg worktree remove` resolves the project root from the worktree path (not CWD),
runs `git worktree remove --force`, and prunes stale metadata. Starting in v1.52.11,
it also **refuses** removal if the caller's CWD is inside the target worktree --
preventing the session-killing CWD corruption bug. v1.53.7 fixed a relative path
resolution bug in this guard: when a relative path was passed while CWD had already
drifted inside the worktree, `filepath.Abs` computed a doubly-nested wrong path and
the guard silently skipped the check. Always prefer the `cd $PROJECT_ROOT &&` prefix.

The `cd $PROJECT_ROOT &&` prefix is belt-and-suspenders: it resets CWD before
removal, and `pvg worktree remove` catches it if you forget.

**Do NOT delete the story branch when removing a worktree.** The worktree is a checkout;
the branch is the record. Story branches are deleted ONLY after merging to the epic branch.

### Branch Locking
Git prevents two worktrees from checking out the same branch ref
simultaneously. The retained dev worktree holds `story/<STORY_ID>` across
the review cycle (it is the resume anchor -- see Semi-Persistent Story
Agents), so any PM worktree must check the story out DETACHED
(`git checkout --detach story/<STORY_ID>`), which git always allows. Only a
plain branch checkout would require removing the dev worktree first.

## CWD Safety (CRITICAL -- read this before any worktree operation)

OpenCode's shell CWD can silently drift into a worktree path after agent
completion or background task resolution. If you then remove that worktree,
your CWD becomes invalid and **every subsequent shell command fails permanently**.
The session is unrecoverable -- you must ask the user to restart OpenCode.

### Defense layers

1. **Layer 1 (prevention): `cd $PROJECT_ROOT &&` prefix.**
   All worktree removal commands MUST be prefixed with an explicit cd:
   ```bash
   cd $PROJECT_ROOT && pvg worktree remove .claude/worktrees/dev-STORY_ID
   ```
   This resets CWD before removal, so even if it had drifted, the shell
   survives the deletion.

2. **Layer 2 (guard): `pvg worktree remove` refuses CWD-inside removal.**
   Starting in v1.52.11, `pvg worktree remove` checks whether the caller's
   CWD is inside the target worktree. If so, it REFUSES the removal with:
   `REFUSED: CWD "..." is inside worktree "..." -- run 'cd ...' first.`
   v1.53.7 fixed a relative path resolution bug: when a relative path was
   passed while CWD had already drifted inside the worktree, the guard
   computed a doubly-nested wrong path and silently skipped the check.

> **No PreToolUse guard in OpenCode:** Unlike Claude Code, OpenCode has no
> PreToolUse hook, so there is no Layer 3 CWD guard. Layer 1 (`cd $PROJECT_ROOT &&`
> prefix) is your primary defense. Never omit it.

### Additional rules

- **NEVER chain branch checkout + worktree add in one shell call:**
  ```bash
  # WRONG -- if checkout changes main worktree, worktree add may fail and
  # leave you on the wrong branch:
  git checkout -b story/X epic/Y && git worktree add .claude/worktrees/dev-X story/X

  # RIGHT -- two separate shell calls:
  git checkout -b story/X epic/Y
  # (then in a SEPARATE call:)
  git worktree add .claude/worktrees/dev-X story/X
  ```

- **After any agent completes, verify CWD:**
  ```bash
  pwd
  ```
  If the output is inside `.claude/worktrees/`, reset immediately:
  ```bash
  cd $PROJECT_ROOT
  ```

- **Use `pvg worktree remove` instead of raw `git worktree remove`.**
  `pvg worktree remove` resolves the project root from the worktree path
  (not from CWD) and enforces the CWD guard.

### Recovery (if CWD is already invalid)

If you see `fatal: Unable to read current working directory` or
`Working directory no longer exists`:

1. Your session shell is corrupted. Raw shell commands will not work.
2. Spawn a cleanup agent (`@paivot-developer`) with instructions to run
   `cd PROJECT_ROOT && git worktree prune && git worktree list` from a fresh shell.
3. After cleanup, escalate to the user: "Shell CWD is unrecoverable. Please
   restart OpenCode from PROJECT_ROOT."
4. Include a summary of remaining work so the next session can resume.

## Post-Compaction Recovery

After context compaction, run recovery:

```bash
pvg loop recover
```

This cleans orphan worktrees, resets orphaned in-progress stories, clears
recorded agent handles (subsequent rework takes the fresh-spawn path), and
outputs a recovery summary.
