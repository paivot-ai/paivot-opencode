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
   pvg nd doctor
   ```
   This checks for:
   - Broken file references
   - Orphaned issues
   - Inconsistent status values
   - Dependency cycle detection

3. **Check current state**:
   ```bash
   pvg loop next --json
   ```

4. **Report recovery summary**:
   - What was cleaned up (orphan worktrees, reset stories)
   - Current backlog state from `pvg loop next` (ready, in-progress, delivered, rejected, blocked, other)
   - Any issues found by `nd doctor`
   - Recommended next action from `pvg loop next`
