---
name: piv-start
description: Single execution pass -- find ready work and dispatch agents
arguments: "[STORY_ID]"
---

# piv-start -- Single Execution Pass

Run a single pass of the execution loop using `pvg` as the source of truth for queue
ordering.

Any direct tracker reads inside this flow must still use `pvg nd ...` so OpenCode never
falls back to a branch-local backlog by accident.

## Steps

1. **Resolve the next action**:
   If `$ARGUMENTS` specifies a STORY_ID, use that story directly.
   Otherwise:
   ```bash
   pvg loop next --json
   ```
   Respect the returned `decision`, `role`, `story_id`, `queue`, `hard_tdd`, and `phase`.

2. **Spawn the returned agent**:
   - `pm_acceptor` -> spawn `@paivot-pm`
   - `developer` -> spawn `@paivot-developer`
   - for hard-tdd with `phase=red`, use the RED/GREEN flow

3. **After the agent finishes**:
   - Scan output for `DISCOVERED_BUG:` blocks. If found, spawn `@paivot-sr-pm` for bug triage.
   - If the developer delivered work, the story should now be `in_progress` with the `delivered` label because `pvg story deliver` handled the transition structurally.
   - If the next action was PM review, let `pvg story accept` / `pvg story reject` own the transition.

4. **Report**:
   Summarize what happened and suggest next action.
