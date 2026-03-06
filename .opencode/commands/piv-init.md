---
name: piv-init
description: Initialize project with git, nd, nd FSM, and D&F document structure
arguments: "[prefix]"
---

# Initialize Paivot Project

Initialize a new project for the Paivot methodology using nd (git-native issue tracker) with FSM enforcement.

## 1. Initialize Git and nd

```bash
# Check if git exists
if [ -d .git ]; then
    echo "Git already initialized - skipping"
else
    git init
fi

# Check if nd exists
if [ -d .nd ]; then
    echo "nd already initialized - skipping"
else
    nd init
fi
```

## 2. Configure nd FSM

Set up the finite state machine for workflow enforcement:

```bash
nd config status_custom "delivered,rejected"
nd config status_sequence "open,in_progress,delivered,closed"
nd config status_exit_rules "blocked:open,in_progress;rejected:in_progress"
nd config status_fsm true
```

This enforces:
- Linear flow: `open -> in_progress -> delivered -> closed` (no skipping)
- Backward rework: any step can regress to earlier steps
- `blocked` can only unblock to `open` or `in_progress`
- `rejected` can only go to `in_progress` (re-work)

## 3. Create Project Structure

```bash
mkdir -p docs .vault/knowledge/{decisions,patterns,debug,conventions}
```

## 4. Auto-Start D&F (Empty Projects Only)

If there are no D&F docs and no issues yet, start Discovery & Framing:

```bash
HAS_DOCS=0
for f in BUSINESS.md DESIGN.md ARCHITECTURE.md; do
    if [ -f "$f" ]; then
        HAS_DOCS=1
        break
    fi
done

ISSUE_COUNT=$(nd list --json 2>/dev/null | jq 'length' 2>/dev/null || echo 0)

if [ "$HAS_DOCS" -eq 0 ] && [ "$ISSUE_COUNT" -eq 0 ]; then
    echo "Empty project detected. Starting Discovery & Framing..."
    echo "Spawning Business Analyst agent first."
fi
```

If D&F should start, spawn BLT agents in sequence:
1. `@paivot-business-analyst` -- produces BUSINESS.md
2. `@paivot-designer` -- produces DESIGN.md
3. `@paivot-architect` -- produces ARCHITECTURE.md

## 5. Verify Initialization

```bash
ls -la .nd/
nd stats
nd config status_fsm
```

## 6. Report Status

After initialization, report:
- Git repository status
- nd initialization status
- FSM configuration
- Next steps (D&F for greenfield, or direct backlog creation for brownfield)
