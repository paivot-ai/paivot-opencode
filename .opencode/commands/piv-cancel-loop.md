---
name: piv-cancel-loop
description: Cancel active execution loop and report backlog state
---

# piv-cancel-loop -- Cancel Execution Loop

Cancel the active piv-loop execution loop and report backlog state.

All live backlog reads must still go through `pvg nd ...` or higher-level `pvg loop ...`
commands so the dispatcher stays on the shared vault.

## Steps

1. Cancel the loop:
   ```bash
   pvg loop cancel
   ```

2. Report current backlog state:
   ```bash
   pvg loop next --json
   ```

3. Summarize:
   - How many iterations completed
   - Counts from `pvg loop next` (ready / in-progress / delivered / rejected / blocked / other)
   - Suggested next action from `pvg loop next` (resume later with `/piv-loop`, or manual triage)
