---
name: vault-evolve
description: Refine vault-backed content based on session experience
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

### Agent prompts (methodology/)
```bash
vlt vault="Claude" files folder="methodology"
vlt vault="Claude" read file="<Agent Name>" follow
```

### Behavioral notes (conventions/)
```bash
vlt vault="Claude" read file="Session Operating Mode" follow
```

### Project-local knowledge (.vault/knowledge/)
```bash
vlt vault=".vault/knowledge" files
```

## Step 3: Determine Scope and Apply

### If `scope: system`:
Create a proposal in `_inbox/`:
```bash
vlt vault="Claude" create name="Proposal -- <Target Note>" path="_inbox/Proposal -- <Target Note>.md" content="---
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
<full current content>" silent
```

### If `scope: project`:
Apply directly:
```bash
vlt vault=".vault/knowledge" patch file="<Note>" heading="<heading>" content="<new content>"
```

## Step 4: Report Changes

Separate into: Proposals Created, Changes Applied, No Changes Needed.
