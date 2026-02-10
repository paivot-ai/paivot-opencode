# Git Workflow for Paivot

**Paivot uses trunk-based development via beads-sync. This is prescriptive, not optional.**

## Core Principle

**Stories are tracked in beads, NOT in git branches.**

Beads' hash-based IDs (`bd-a1b2`) eliminate merge collisions when multiple agents work concurrently on the same branch. The intelligent 3-way merge driver resolves field-level conflicts automatically. Feature branching defeats this architecture.

## Branch Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                        Protected Main Branch                     │
│                   (Requires PR for direct pushes)                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Periodic PR merges
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                      beads-sync Branch                           │
│              (Auto-managed via internal worktree)                │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Agent A     │  │  Agent B     │  │  Agent C     │          │
│  │  Workspace   │  │  Workspace   │  │  Workspace   │          │
│  │  (Story 1)   │  │  (Story 2)   │  │  (Story 3)   │          │
│  │              │  │              │  │              │          │
│  │  Daemon      │  │  Daemon      │  │  Daemon      │          │
│  │  Auto-sync   │  │  Auto-sync   │  │  Auto-sync   │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                    │
│         └─────────────────┴─────────────────┘                    │
│              All commit to beads-sync concurrently               │
└──────────────────────────────────────────────────────────────────┘

Git is the coordinator - no central server needed
Hash-based IDs eliminate merge collisions
Intelligent 3-way merge driver resolves field-level conflicts
```

## Why Trunk-Based Development

### Hash-Based ID Collision Avoidance

Multiple agents creating issues concurrently:
- Agent A creates `bd-a1b2` at 10:00
- Agent B creates `bd-c3d4` at 10:01
- Both sync to beads-sync
- Merge driver sees different hash IDs - no conflict
- Both issues coexist in `issues.jsonl`

### Field-Level Merge Intelligence

If two agents modify the same issue:
- Agent A: `bd update bd-a1b2 --status in_progress` (10:00)
- Agent B: `bd label add bd-a1b2 urgent` (10:01)
- Merge driver combines: status=in_progress + labels=[urgent]
- No manual conflict resolution needed

### Daemon Prevents SQLite Lock Conflicts

Per-workspace daemon model:
- Each agent's workspace has its own `.beads/beads.db`
- Each has its own daemon process (`.beads/bd.sock`)
- No cross-process SQLite locking issues
- RPC batching optimizes performance
- 30-second debounce batches changes automatically

## Initial Setup (One-Time)

```bash
# 1. Initialize with sync-branch mode
cd ~/workspace/myproject
bd init --branch beads-sync

# 2. Configure GitHub branch protection on main
# (via GitHub UI: Settings → Branches → Add rule for 'main')

# 3. Create initial PR from beads-sync to main
git push -u origin beads-sync
gh pr create --base main --head beads-sync \
  --title "Beads sync branch (keep open)" \
  --body "Auto-managed beads synchronization. Merge periodically."
```

## Daily Workflow (Per Agent/Orchestrator)

```bash
# Morning sync
git pull --rebase origin beads-sync

# Work happens - developers spawn, implement, deliver
# Daemon auto-syncs every 30 seconds

# Evening: Land the plane (MANDATORY)
bd sync           # Force immediate sync (bypasses debounce)
git pull --rebase origin beads-sync  # Get latest changes
git push origin beads-sync            # Push your work

# Verify success
git status  # Should show "up to date with origin/beads-sync"
```

## Story Lifecycle (No Branches)

```bash
# Agent picks up story (orchestrator dispatches)
bd ready  # Shows bd-a1b2 as available
bd update bd-a1b2 --status in_progress

# Agent implements, tests, commits to beads-sync
git add src/auth/login.go
git commit -m "feat: implement login (bd-a1b2)"
git push origin beads-sync

# Agent marks done
bd label add bd-a1b2 delivered

# Daemon syncs to beads-sync automatically
# Story is now visible to all agents via git pull
```

## Merging to Main (Periodic, Human-Driven)

```bash
# Once per day/sprint/milestone, review accumulated changes:
gh pr view 123  # Review the beads-sync → main PR
gh pr checks 123  # Verify CI passes

# Merge via GitHub UI (or CLI)
gh pr merge 123 --merge --delete-branch=false

# Sync-branch persists (don't delete it)
# Next changes continue on beads-sync → main PR updates automatically
```

## When NOT to Branch (95% of cases)

Use trunk-based (beads-sync) when:
- ✅ Working on INVEST stories (< 2 days work)
- ✅ Multiple agents on different stories
- ✅ Changes are independent (can deploy separately)
- ✅ Want fast integration and feedback
- ✅ Team uses beads dependencies for ordering
- ✅ Protected main branch (requires PR)

## When TO Branch (5% of cases - RARE)

Create feature branch when:
- ⚠️ Architectural experiment (> 1 week, may discard)
- ⚠️ Long-running work that cannot integrate incrementally
- ⚠️ Breaking changes affecting many agents

**CRITICAL:** When branching, disable daemon:
```bash
git checkout -b experiment/new-architecture
export BEADS_NO_DAEMON=1  # Daemon doesn't handle branches correctly

# Or configure permanently for this workspace
bd config set sync.daemon false
```

## Anti-Patterns to Avoid

### ❌ Branch per Story
```bash
# DON'T DO THIS
git checkout -b feature/bd-a1b2-login
git checkout -b feature/bd-c3d4-profile
# Now you have N branches to manage, merge, rebase...
```

**Why it's bad:**
- Daemon conflicts (commits to wrong branch)
- Merge overhead multiplies
- Defeats beads' hash-based collision avoidance
- Agents waste time on git, not delivering value

**Do this instead:**
```bash
# All agents work on beads-sync
git checkout beads-sync
# Work, daemon syncs automatically
# Done. No branch management.
```

### ❌ Branch per Agent
```bash
# DON'T DO THIS
git checkout -b agent-a-work
git checkout -b agent-b-work
```

**Why it's bad:**
- Destroys visibility across agents
- Integration happens too late
- Merge conflicts accumulate

**Do this instead:**
```bash
# All agents share beads-sync, separate workspace directories
# Agent A: ~/workspaces/agent-a/myproject (beads-sync)
# Agent B: ~/workspaces/agent-b/myproject (beads-sync)
```

### ❌ Long-Lived Feature Branches
```bash
# DON'T DO THIS
git checkout -b feature/new-dashboard
# ... 3 weeks later ...
# ... 500 commits behind main ...
# ... merge conflict hell ...
```

**Do this instead:**
```bash
# Break into small INVEST stories
bd create --title "Dashboard: Add header component"  # 1 day
bd create --title "Dashboard: Add metrics widget"    # 1 day
bd create --title "Dashboard: Add charts"            # 2 days

# Set dependencies
bd dep add bd-header --blocks bd-metrics

# Agents pick up sequentially, all on beads-sync
# Continuous integration, fast feedback
```

## Conflict Resolution (Rare)

Despite intelligent merging, conflicts can happen:

```bash
# After pull, if conflict in issues.jsonl:
git status  # Shows conflict in .beads/issues.jsonl

# Option 1: Accept remote (safest)
git checkout --theirs .beads/issues.jsonl
bd import -i .beads/issues.jsonl
git add .beads/issues.jsonl
git rebase --continue

# Option 2: Manual merge (advanced)
bd merge .beads/issues.jsonl.ours .beads/issues.jsonl.base \
         .beads/issues.jsonl.ours .beads/issues.jsonl.theirs
git add .beads/issues.jsonl
git rebase --continue
```

## Per-Agent Workspace Setup

Each agent works in a separate directory clone (NOT git worktrees):

```bash
# Agent A workspace
cd ~/workspaces/agent-a
git clone git@github.com:org/repo.git myproject-agent-a
cd myproject-agent-a
git checkout beads-sync  # All agents work on beads-sync

# Agent starts daemon automatically on first bd command
bd list  # Daemon starts, begins auto-syncing

# Verify daemon is running
bd daemon status
```

**Why separate directories, not worktrees?**
- Daemon doesn't handle user-created worktrees reliably
- Separate directories = separate daemons = no conflicts
- Beads sync-branch mode uses internal worktrees (different)

## Performance Characteristics

### Scalability Limits
- **Agents per Repository:** Tested up to 10 concurrent agents
- **Issues per Workspace:** Handles 10,000+ issues efficiently
- **Sync Frequency:** 30-second debounce (configurable)
- **Daemon Memory:** ~30-35 MB per workspace
- **JSONL Size:** ~1KB per issue (git handles MBs easily)

### Bottlenecks to Watch
1. **Git Push Frequency:** Too many agents → push conflicts
   - Mitigation: Daemon batches (30s), agents pull before push

2. **SQLite Database Size:** Large issue count → slower queries
   - Mitigation: Use indexes (automatic), compact old issues

3. **Merge Conflict Rate:** Rare but possible if same issue modified
   - Mitigation: INVEST independence, hash-based IDs

## Troubleshooting

### Problem: Agent can't push to beads-sync

```bash
# Symptom
git push origin beads-sync
# ! [rejected] beads-sync -> beads-sync (non-fast-forward)

# Solution
git pull --rebase origin beads-sync
git push origin beads-sync
```

### Problem: Daemon not syncing

```bash
# Check daemon status
bd daemon status

# Restart daemon
bd daemon stop
bd list  # Auto-starts daemon

# Force immediate sync
bd sync
```

### Problem: Changes not visible to other agents

```bash
# Verify push succeeded
git status  # Should show "up to date with origin/beads-sync"

# Check remote
git log origin/beads-sync -1  # Should show your recent commit

# Other agent: pull to see changes
git pull origin beads-sync
bd list  # Should show updated issues
```

## CI/CD Integration

```yaml
# .github/workflows/beads-validation.yml
name: Beads Validation
on:
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install beads
        run: |
          curl -sSL https://github.com/rneatherway/beads/releases/latest/download/bd-linux-amd64 -o /usr/local/bin/bd
          chmod +x /usr/local/bin/bd

      - name: Validate beads data integrity
        run: |
          bd import -i .beads/issues.jsonl
          bd list --format json | jq -e 'length >= 0'

      - name: Check for orphan dependencies
        run: |
          bd list --format json | \
            jq -e 'all(.[]; .dependencies | all(.issue_id; . as $id | any(..; .id == $id)))'
```

## Summary

| Aspect | Feature Branches | Trunk-Based (Paivot) |
|--------|------------------|----------------------|
| **Branches per Story** | One per story | One shared (beads-sync) |
| **Merge Overhead** | High (N PRs) | Low (1 persistent PR) |
| **Daemon Compatibility** | Requires `--no-daemon` | Full daemon support |
| **Conflict Rate** | Moderate | Very low (hash IDs) |
| **Work Isolation** | Git branches | Beads dependencies |
| **Agent Setup Time** | ~5 min/story | ~1 min one-time |
| **Cognitive Load** | High (git state) | Low (just code) |
| **Parallel Work** | Limited by branches | Unlimited (hash IDs) |
| **CI/CD Integration** | Per-branch | Single pipeline |

## Key Takeaways

1. **Stop using branches for stories.** Stories = beads issues. Branches = release gates.

2. **Hash-based IDs eliminate collisions.** Multiple agents can work on beads-sync simultaneously without conflicts.

3. **Daemon handles sync transparently.** Agents focus on code, not git state.

4. **Scales effortlessly.** 10+ concurrent agents, no branch management overhead.

5. **This is prescriptive.** The system architecture assumes trunk-based development. Feature branching defeats beads' design.

---

**Mental Model Shift:**
- Before: "Story = Branch"
- After: "Story = Beads Issue, Branch = Release Gate"
