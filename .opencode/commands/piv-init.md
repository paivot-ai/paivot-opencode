---
name: piv-init
description: Initialize project with git, nd, nd FSM, and D&F document structure
arguments: "[prefix]"
---

# Initialize Paivot Project

Initialize a new project for the Paivot methodology using nd plus pvg-managed workflow settings.

## 1. Initialize Git and nd

```bash
# Check if git exists
if [ -d .git ]; then
    echo "Git already initialized - skipping"
else
    git init
fi

# Ensure Paivot runtime directories exist
mkdir -p .vault .vault/knowledge/{decisions,patterns,debug,conventions}

# Track the shared nd resolver config in the repo
if [ ! -f .vault/.nd-shared.yaml ]; then
cat > .vault/.nd-shared.yaml <<'EOF'
# nd shared-worktree state
mode: git_common_dir
path: paivot/nd-vault
EOF
fi

# Initialize the shared live nd vault (outside branch checkouts)
SHARED_ND_VAULT=$(pvg nd root --ensure)
echo "Shared nd vault: $SHARED_ND_VAULT"
```

## 2. Configure nd FSM

Set up the base finite state machine for workflow enforcement:

```bash
pvg settings \
  workflow.fsm=true \
  workflow.sequence=open,in_progress,closed \
  workflow.custom_statuses=rejected \
  'workflow.exit_rules=blocked:open,in_progress;rejected:in_progress'
```

This enforces:
- Base flow: `open -> in_progress -> closed` (no skipping)
- Backward rework: any step can regress to earlier steps
- `blocked` can only unblock to `open` or `in_progress`
- `rejected` can only go to `in_progress` when used as an escape status

Paivot delivery semantics still use the shared contract:
- `delivered` = nd `in_progress` + `delivered` label
- `accepted` = nd `closed` + `accepted` label
- `rejected` = nd `open` + `rejected` label

## 3. Create Project Structure

```bash
mkdir -p docs
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

ISSUE_COUNT=$(pvg nd list --json 2>/dev/null | jq 'length' 2>/dev/null || echo 0)

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
ls -la .vault/
pvg nd stats
pvg settings workflow.fsm
```

## 6. Report Status

After initialization, report:
- Git repository status
- nd initialization status
- FSM configuration
- Next steps (D&F for greenfield, or direct backlog creation for brownfield)
