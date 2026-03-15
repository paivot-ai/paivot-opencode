---
name: piv-cancel-loop
description: Cancel active execution loop and report backlog state
---

# piv-cancel-loop -- Cancel Execution Loop

Cancel the active piv-loop execution loop and report backlog state.

## Steps

1. Cancel the loop:
   ```bash
   pvg loop cancel
   ```

2. Report current backlog state:
   ```bash
   pvg nd ready --json | jq length
   pvg nd list --status in_progress --json | jq length
   pvg nd list --status in_progress --label delivered --json | jq length
   pvg nd list --status open --label rejected --json | jq length
   pvg nd blocked --json | jq length
   ```

3. Summarize:
   - How many iterations completed
   - Stories still ready / in-progress / delivered / rejected / blocked
   - Suggest next action (resume later with `/piv-loop`, or manual triage)
