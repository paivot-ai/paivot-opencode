---
name: vault-evolve
description: Refine vault knowledge based on session experience. Capture learned patterns, decisions, and debug insights. Agent prompts are self-contained in agent .md files (not vault). System-scoped notes get proposals; project-scoped notes get direct edits.
---

# Vault Evolve -- Refine Vault Content from Experience

Review the current session's work and refine the vault notes that power Paivot.

**Vault:** `vlt vault="Claude"` (resolves path dynamically)

**Scope rules:**
- `scope: system` -- propose changes only; user must approve via `/vault-triage`
- `scope: project` -- apply changes directly to `.vault/knowledge/`

## Step 1: Assess What Happened

Review the conversation. Identify friction, patterns, decisions, and improvements.

## Step 2: Identify Vault Notes to Update

### Learned knowledge (patterns/, decisions/, debug/)
```bash
pvg notes list --folder "patterns"
pvg notes list --folder "decisions"
pvg notes list --folder "debug"
```

Agent operational prompts are self-contained in `.opencode/agent/` files (not in the vault).
To change agent behavior, update the agent .md file and commit to the repo.
vault-evolve captures LEARNED KNOWLEDGE that agents can consult -- not operational rules.

### Behavioral notes (conventions/)
```bash
pvg notes read "Session Operating Mode"
# TODO: pvg notes addresses by full path; if not at vault root use the full path.
# `follow` semantic has no pvg equivalent yet -- fall back to vlt for that.
```

### Project-local knowledge (.vault/knowledge/)
```bash
vlt vault=".vault/knowledge" files
# Project-local vault still uses vlt directly; pvg notes addresses the configured vault only.
```

## Step 3: Determine Scope and Apply

### If `scope: system`:
Create a proposal in `_inbox/`:
```bash
pvg notes create "_inbox/Proposal -- <Target Note>.md" --title "Proposal -- <Target Note>" --body "---
type: proposal
scope: system
target: \"<target note path>\"
project: <project>
status: pending
created: <YYYY-MM-DD>
---

# Proposed change: <Target Note>

## Motivation
<session experience>

## Change
### Before
<current section>

### After
<proposed replacement>

## Snapshot (for rollback)
<full current content>"
# (vlt-only `silent` flag dropped)
```

### If `scope: project`:
Apply directly:
```bash
vlt vault=".vault/knowledge" patch file="<Note>" heading="<heading>" content="<new content>"
```

## Step 4: Report Changes

Separate into: Proposals Created, Changes Applied, No Changes Needed.
