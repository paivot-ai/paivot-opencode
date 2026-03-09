---
name: piv-recover
description: Recover from crash or inconsistent state using pvg + nd doctor
---

# piv-recover -- Crash Recovery

Recover from a crash, context compaction, or inconsistent state.

## Steps

1. **Run pvg recovery**:
   ```bash
   pvg loop recover
   ```
   This automatically:
   - Reads the snapshot file (if one exists)
   - Removes orphan worktrees and their branches
   - Resets orphaned in-progress stories to `open` in nd (delivered stories preserved)
   - Outputs a recovery summary

2. **Run nd health check**:
   ```bash
   nd doctor
   ```
   This checks for:
   - Broken file references
   - Orphaned issues
   - Inconsistent status values
   - Dependency cycle detection

3. **Check current state**:
   ```bash
   nd list --status in_progress --json
   nd list --status in_progress --label delivered --json
   nd list --status open --label rejected --json
   nd ready --json | jq length
   nd blocked --json | jq length
   ```

4. **Report recovery summary**:
   - What was cleaned up (orphan worktrees, reset stories)
   - Current backlog state (ready, in-progress, delivered, rejected, blocked)
   - Any issues found by `nd doctor`
   - Recommended next action:
     - If ready work exists: "Run `/piv-loop` to resume execution"
     - If delivered work exists: "Run `/piv-start` to process delivered stories"
     - If everything is blocked: "Manual intervention needed -- check blocked stories"
