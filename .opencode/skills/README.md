# Paivot OpenCode Skills

This directory contains vendor-agnostic skills for the Paivot methodology, compatible with any LLM provider through OpenCode.

## Available Skills

### 1. paivot-methodology
**Path:** `.opencode/skills/paivot-methodology/SKILL.md`

**Description:** Comprehensive guide to the Paivot modified Pivotal methodology for AI agents. Covers:
- Discovery & Framing (D&F) process
- Backlog management and story execution
- Testing philosophy (unit, integration, E2E)
- Delivery workflow with evidence-based reviews
- Retrospectives and learnings lifecycle
- Milestone validation protocol
- Git workflow (trunk-based with beads-sync)
- Agent role boundaries and failure modes

**Auto-activates when:**
- `.beads/` directory exists in project
- User mentions Paivot/Pivotal patterns
- `bd` commands are used

**Version:** 1.0.0

---

### 2. paivot-orchestrator
**Path:** `.opencode/skills/paivot-orchestrator/SKILL.md`

**Description:** FSM-enforced orchestrator for Paivot execution loops. The orchestrator is a dispatcher that:
- Uses `piv next` to determine all actions
- Spawns appropriate agents based on FSM recommendations
- Never makes independent decisions
- Enforces workflow via PreToolUse hooks

**When to use:**
- Running execution loops (`/piv-loop`, `/piv-start`)
- Executing backlogs
- Managing pipeline execution

**Key principle:** The orchestrator NEVER decides - it only executes what the FSM commands.

**Version:** 1.1.0

---

## Key Differences from Claude Code Version

### 1. Agent Spawning Syntax
OpenCode uses `@agent-name` syntax instead of `Task()` function calls:

```python
# OpenCode
@pivotal-developer
# Task: Implement story bd-xxxx

# Claude Code (old)
Task(
    subagent_type="pivotal-developer",
    prompt="Implement story bd-xxxx",
    description="Dev: bd-xxxx"
)
```

### 2. Vendor-Agnostic
- No references to "Claude" - uses "AI agents" instead
- No platform-specific paths (`.claude/` removed)
- Works with any LLM provider via OpenCode

### 3. Trunk-Based Git Workflow
All references updated to use `beads-sync` as the trunk branch:
- ALL commits go to `beads-sync`
- No feature branches per story
- Periodic merges to `main` via PR

### 4. FSM Integration Preserved
All FSM integration, state management, and enforcement logic remains unchanged:
- `piv next` for action determination
- Hook-based enforcement
- Event firing by agents
- Priority ordering

## Usage

Skills are automatically loaded by OpenCode based on:
1. **Trigger patterns** - Keywords in user messages
2. **File patterns** - Presence of specific files/directories
3. **Explicit invocation** - User requests specific skill

The Paivot skills work together:
- **methodology** provides the comprehensive working agreement
- **orchestrator** provides the execution dispatcher logic

Both skills integrate seamlessly with the `piv` CLI tool and FSM for enforcement.

## Compatibility

These skills support projects in:
- Go
- TypeScript
- Python
- JavaScript
- Rust

The methodology itself is language-agnostic - the skills just ensure proper support for these languages.
