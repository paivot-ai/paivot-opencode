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
   .opencode/scripts/paivot-nd.sh ready --json | jq length
   .opencode/scripts/paivot-nd.sh list --status in_progress --json | jq length
   .opencode/scripts/paivot-nd.sh list --status in_progress --label delivered --json | jq length
   .opencode/scripts/paivot-nd.sh list --status open --label rejected --json | jq length
   .opencode/scripts/paivot-nd.sh blocked --json | jq length
   ```

3. Summarize:
   - How many iterations completed
   - Stories still ready / in-progress / delivered / rejected / blocked
   - Suggest next action (resume later with `/piv-loop`, or manual triage)
