---
name: piv-retro
description: Manually invoke a retrospective on a completed epic
arguments: "<EPIC_ID>"
---

# piv-retro -- Manual Retrospective

Trigger a retrospective for a completed (or in-progress) epic.

## Steps

1. **Validate the epic**:
   ```bash
   nd show $ARGUMENTS --json
   ```
   Verify it exists and is an epic.

2. **Check completion status**:
   ```bash
   nd children $ARGUMENTS --json | jq '[.[] | select(.status != "closed")] | length'
   ```
   If open stories remain, warn but proceed (user explicitly requested retro).

3. **Spawn retro agent**:
   Spawn `@paivot-retro` with:
   ```
   Run retrospective for epic $ARGUMENTS.
   Extract LEARNINGS from all accepted stories, analyze patterns,
   distill actionable insights, and write to .vault/knowledge/
   with actionable: pending frontmatter tag.
   ```

4. **Report**:
   After the retro agent completes, summarize:
   - Number of insights captured
   - Categories (testing, architecture, process, tooling, etc.)
   - Where insights were written (`.vault/knowledge/<subfolder>`)
   - Remind: "Sr PM will incorporate pending insights into upcoming stories"
