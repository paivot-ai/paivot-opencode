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
workflow.sequence: open,in_progress,closed
workflow.exit_rules: blocked:open,in_progress;rejected:in_progress
workflow.custom_statuses: rejected
dnf.domain_model: false
architecture.c4: false
loop.persist_across_sessions: true
lint.quality_gates:
lint.brownfield: false
```

Notes on selected settings:

- `dnf.domain_model` (default `false`): when enabled, the Architect maintains a
  `*.modelith.yaml` domain model as the machine-checkable twin of ARCHITECTURE.md;
  the Sr PM turns invariants into acceptance criteria and the Anchor checks
  entity/invariant coverage. Requires the `modelith` CLI (`pvg setup`/`update`).
- `loop.persist_across_sessions` (default `true`): the execution loop survives
  session boundaries -- agent completions resume it where it left off. Set
  `false` to clear loop state when the session exits, even if work remains.
- `lint.quality_gates`: extra quality-gate patterns (pipe-separated) that the
  `walking-skeleton` check of `pvg lint --backlog` requires in every skeleton's
  AC, on top of its generic defaults. Populated by the Sr PM from the project
  hard rules extracted during Phase 1 ingestion.
  Example: `"no.skip.if.missing|no mocks? in integration|always TDD"`
- `lint.brownfield` (default `false`): force the `paths-exist` lint check on,
  regardless of the >50-commits heuristic. The check verifies every path
  referenced in a story body exists on disk or in a PRODUCES block.

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
