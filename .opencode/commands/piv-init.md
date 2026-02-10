---
name: piv-init
description: Initialize project with git and beads
arguments: "[prefix]"
---

# Initialize Paivot Project

You are initializing a new project for the Paivot methodology. Execute the following steps:

## 1. Initialize Git and Beads

The user may have provided a prefix argument: `$ARGUMENTS`

**Check existing state first:**

```bash
# Check if git exists
if [ -d .git ]; then
    echo "Git already initialized - skipping"
else
    git init
fi

# Check if beads exists
if [ -d .beads ]; then
    echo "Beads already initialized - skipping"
else
    # Initialize with sync-branch mode for trunk-based development
    # If prefix was provided, use it
    if [ -n "$ARGUMENTS" ]; then
        bd init --branch beads-sync --prefix "$ARGUMENTS"
    else
        bd init --branch beads-sync
    fi
fi
```

**Run quickstart regardless** (it's idempotent):
```bash
bd quickstart
```

**Configure GitHub branch protection** (recommended):
After initialization, configure GitHub to protect `main` branch (requires PR for merges). The `beads-sync` branch will accumulate work and be merged to `main` periodically via PR.

## 2. Initialize the FSM (if available)

If `piv` is installed, initialize the FSM tables:

```bash
if command -v piv >/dev/null 2>&1; then
    piv init
    piv config set enforcement_enabled true
else
    echo "piv not found in PATH; D&F will proceed without FSM enforcement."
fi
```

## 3. Create Project Structure

Create the D&F document directories:

```bash
mkdir -p docs
```

## 4. Auto-Start D&F (Empty Projects Only)

If there are no D&F docs and no issues yet, start Discovery & Framing by
triggering the FSM and spawning the BLT agents.

```bash
HAS_DOCS=0
for f in docs/BUSINESS.md docs/DESIGN.md docs/ARCHITECTURE.md; do
    if [ -f "$f" ]; then
        HAS_DOCS=1
        break
    fi
done

ISSUE_COUNT=$(bd list --json 2>/dev/null | jq 'length' 2>/dev/null || echo 0)

if [ "$HAS_DOCS" -eq 0 ] && [ "$ISSUE_COUNT" -eq 0 ]; then
    if command -v piv >/dev/null 2>&1; then
        piv event start_d_and_f
    fi
fi
```

If `piv event start_d_and_f` was triggered, call `piv next` and spawn the
recommended BLT agent(s) (BA, Designer, Architect) until `piv next` returns
`wait` or `spawn_sr_pm`.

Example agent invocation:

```
Invoke the agent:
@pivotal-ba "Conduct discovery. Document findings in docs/BUSINESS.md. ALL commits go to beads-sync."
```

## 5. Verify Initialization

Confirm the setup is correct:

```bash
ls -la .beads/
ls -la .git/
```

## 6. Report Status

After initialization, report to the user:
- Git repository status
- Beads initialization status
- Next steps (D&F already started for empty projects; otherwise run D&F or brownfield execution)

## Notes

- **Safe to run multiple times** - checks for existing git/beads and skips if present
- The `bd quickstart` command is idempotent and can be re-run safely
- For brownfield projects, users can skip D&F and directly create stories with Sr. PM

After initialization, remind the user they can:
- Start Discovery & Framing with the BLT (Business Analyst, Designer, Architect)
- For brownfield: directly spawn Sr. PM to create backlog from existing context
