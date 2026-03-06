---
name: vault-settings
description: View and configure paivot-opencode settings for the current project
arguments: "[key=value]"
---

# Vault Settings

Manage paivot-opencode configuration for the current project. Settings are stored in
`.vault/knowledge/.settings.yaml`.

## Step 1: Load Current Settings

```bash
pvg settings
```

If pvg is not available:
```bash
cat .vault/knowledge/.settings.yaml 2>/dev/null || echo "not found"
```

Defaults:
```yaml
project_vault_git: ask
default_scope: system
proposal_expiry_days: 30
session_start_max_notes: 10
auto_init_project_vault: ask
stack_detection: false
workflow.fsm: true
workflow.sequence: open,in_progress,delivered,closed
workflow.exit_rules: blocked:open,in_progress;rejected:in_progress
workflow.custom_statuses: delivered,rejected
architecture.c4: false
loop.persist_across_sessions: false
```

## Step 2: Present Current Configuration

Show settings as a table with setting name, current value, and description.

## Step 3: Apply Changes

If arguments provided (e.g., `/vault-settings project_vault_git=tracked`), apply directly:
```bash
pvg settings <key>=<value>
```

Otherwise, ask what to change.

## Step 4: Report

Show what changed and any side effects.
