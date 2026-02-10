# Skills Porting Summary

## Overview
Successfully ported 2 skills from Claude Code format to OpenCode format:
- `/Users/ramirosalas/workspace/paivot/paivot-opencode/.opencode/skills/paivot-methodology/SKILL.md`
- `/Users/ramirosalas/workspace/paivot/paivot-opencode/.opencode/skills/paivot-orchestrator/SKILL.md`

## Key Changes Made

### 1. YAML Frontmatter Structure
**Before (Claude Code):**
```yaml
---
name: Paivot Methodology
description: >-
  Use when working on projects...
version: 1.0.0
---
```

**After (OpenCode):**
```yaml
---
name: paivot-methodology
description: >-
  Use when working on projects...
version: 1.0.0
license: MIT
compatibility: ["go", "typescript", "python", "javascript", "rust"]
---
```

Changes:
- Name changed to lowercase with hyphens (OpenCode convention)
- Added `license: MIT` field
- Added `compatibility` array listing supported languages

### 2. Agent Spawning Syntax
**Before (Claude Code):**
```python
Task(
    subagent_type="pivotal-developer",
    prompt="Implement story...",
    description="Dev: bd-xxxx"
)
```

**After (OpenCode):**
```python
@pivotal-developer
# Task: Implement story...
```

Changes:
- Replaced `Task()` function calls with `@agent-name` syntax
- Task description embedded as comments
- More concise, vendor-agnostic format

### 3. Branch References
**Before:**
- Mixed references to "main" and feature branches

**After:**
- Consistent use of `beads-sync` as the trunk branch
- All git workflow examples reference `beads-sync`
- Explicit documentation that ALL commits go to `beads-sync`

### 4. Vendor-Agnostic Language
**Before:**
- References to "Claude" and "Claude agents"
- Claude Code-specific paths like `.claude/`
- Claude-specific terminology

**After:**
- Changed to "AI agents" and "main agent"
- Removed all "Claude" references
- Generic references to "config file" instead of specific paths
- Platform-agnostic terminology throughout

### 5. Platform-Specific Path References
**Before:**
```yaml
Check `.claude/paivot.local.md` for parallelization limits
```

**After:**
```yaml
Check `.local.md` (or platform config) for parallelization limits
```

Changes:
- Removed `.claude/` path prefix
- Made references generic to work across platforms
- Mentioned "platform config" as alternative

## File Statistics

| File | Line Count | Size |
|------|-----------|------|
| paivot-methodology/SKILL.md | 961 lines | Comprehensive methodology guide |
| paivot-orchestrator/SKILL.md | 384 lines | FSM orchestrator instructions |

## What Was Preserved

The following critical content was preserved unchanged:
- All FSM integration logic and state management
- Complete testing philosophy and requirements
- Delivery workflow and proof requirements
- Retrospective and learnings lifecycle
- Milestone validation protocol
- Discovery & Framing process
- All role boundaries and failure modes
- "See Something, Say Something" principle
- External repository access rules
- Git workflow details

## Verification

Verified that:
- ✅ No `Task()` function calls remain
- ✅ All agent spawning uses `@agent-name` syntax
- ✅ No "Claude" references exist
- ✅ All branch references updated to `beads-sync`
- ✅ YAML frontmatter includes required OpenCode fields
- ✅ All FSM integration preserved
- ✅ No platform-specific paths remain

## Next Steps

These skills are now ready for use in OpenCode with any LLM provider. The FSM integration, testing philosophy, and methodology remain fully intact while being vendor-agnostic.
