---
name: piv-start
description: Single execution pass -- find ready work and dispatch agents
arguments: "[STORY_ID]"
---

# piv-start -- Single Execution Pass

Run a single pass of the execution loop. Find the highest-priority ready work and dispatch
one developer agent to implement it.

## Steps

1. **Check for delivered work first** (PM-Acceptor has priority):
   ```bash
   .opencode/scripts/paivot-nd.sh list --status in_progress --label delivered --json
   ```
   If any stories are delivered, spawn `@paivot-pm` to review the first one.

2. **Check for rejected work** (fix before new work):
   ```bash
   .opencode/scripts/paivot-nd.sh list --status open --label rejected --json
   ```
   If any stories are rejected, spawn `@paivot-developer` to address the first one.

3. **Find ready work**:
   If `$ARGUMENTS` specifies a STORY_ID, use that story directly.
   Otherwise:
   ```bash
   .opencode/scripts/paivot-nd.sh ready --sort priority --json
   ```
   Pick the highest-priority item.

4. **Check for hard-tdd**:
   ```bash
   .opencode/scripts/paivot-nd.sh show <id> --json | grep -q '"hard-tdd"'
   ```
   If present, use two-phase flow (RED then GREEN). Otherwise, normal mode.

5. **Spawn developer**:
   Spawn `@paivot-developer` with the story context.
   Wait for completion.

6. **After developer finishes**:
   - Scan output for `DISCOVERED_BUG:` blocks. If found, spawn `@paivot-sr-pm` for bug triage.
   - The story should now be `in_progress` with the `delivered` label.
   - Spawn `@paivot-pm` to review the delivered story.

7. **Report**:
   Summarize what happened and suggest next action.
