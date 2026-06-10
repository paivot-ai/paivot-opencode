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

2. Report current backlog state (the loop is cancelled, so query the tracker directly):
   ```bash
   pvg issues ready --json | jq length
   pvg issues list --status in_progress --json | jq length
   pvg issues blocked --json | jq length
   ```

3. Summarize:
   - How many iterations completed
   - Stories still ready / in-progress / blocked
   - Suggested next action (resume later with `/piv-loop`, or manual triage)
