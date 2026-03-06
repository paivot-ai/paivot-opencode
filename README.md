<p align="center">
  <img src="docs/paivot.png" alt="Paivot Logo" width="200">
</p>

# Paivot for OpenCode

**A structured software development methodology for AI coding agents, implemented for [OpenCode](https://www.opencode.ai/).**

Paivot adapts the [Pivotal Labs methodology](docs/pivotal_methodology.md) -- the disciplined system of balanced teams, Discovery & Framing, and XP engineering practices that Pivotal Labs used to ship software for decades -- for a world where the builders are AI agents rather than human teams.

This is the OpenCode port of [paivot-graph](https://github.com/paivot-ai/paivot-graph) (the Claude Code plugin). The methodology is identical; only the runtime format differs.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| [OpenCode](https://www.opencode.ai/) | AI coding agent framework | [docs.opencode.ai](https://docs.opencode.ai/installation) |
| [nd](https://github.com/RamXX/nd) | Git-native issue tracker with FSM | `git clone && make install` |
| [pvg](https://github.com/paivot-ai/pvg) | Loop lifecycle and guard CLI | `gh release download -R paivot-ai/pvg` |
| [vlt](https://github.com/RamXX/vlt) | Vault CLI for knowledge management | `git clone && make install` |
| LLM API key | Anthropic recommended (Opus/Sonnet) | Provider-specific |

Optional:
- [Go](https://go.dev/dl/) 1.22+ -- only needed to build pvg/nd from source

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/paivot-ai/paivot-opencode.git
cd paivot-opencode

# 2. Verify dependencies
make check-deps

# 3. Install the vlt skill (for vault-backed agents)
make fetch-vlt-skill

# 4. Copy to your project
cp -r .opencode opencode.json AGENTS.md /path/to/your-project/

# 5. Initialize in your project
cd /path/to/your-project
opencode
# Then in OpenCode:
/piv-init [PREFIX]
```

For empty projects, `/piv-init` automatically begins Discovery & Framing.

---

## How It Works

### nd FSM -- Workflow Enforcement Without Hooks

OpenCode does not have Claude Code's JSON hook system. Instead, Paivot uses **nd's built-in finite state machine** to enforce workflow transitions:

```
open --> in_progress --> delivered --> closed
                ^           |
                |           v
              rejected
```

Configuration (set by `/piv-init`):

```yaml
status_custom: "delivered,rejected"
status_sequence: "open,in_progress,delivered,closed"
status_exit_rules: "blocked:open,in_progress;rejected:in_progress"
status_fsm: true
```

nd **rejects invalid transitions** at the CLI level. A developer cannot mark a story `closed` (only `delivered`). A PM cannot close a story that hasn't been delivered. The FSM is passive enforcement -- no hooks needed.

### Dispatcher Pattern

When Paivot is invoked, the main OpenCode session becomes a **dispatcher** that:
- Queries nd for work (`nd list --status delivered`, `nd ready`)
- Spawns specialized agents (`@paivot-developer`, `@paivot-pm`, etc.)
- Relays questions from agents to the user
- Never writes code, D&F documents, or stories itself

### Three-Tier Knowledge Model

| Tier | Location | Scope | Governance |
|------|----------|-------|------------|
| System vault | Obsidian "Claude" (via `vlt`) | All projects | Proposals require approval |
| Project vault | `.vault/knowledge/` | Single project | Direct edits |
| Session context | Ephemeral | Current session | Automatic |

### Vault-Backed Agents

Agent prompts are **thin loaders** that read full instructions from the Obsidian vault at runtime:

```bash
vlt vault="Claude" read file="Sr PM Agent"
```

If the vault is unavailable, each agent has embedded fallback instructions. This means the methodology lives in one place (the vault) and stays current across all projects.

---

## Agents

| Agent | Model | Role |
|-------|-------|------|
| `@paivot-sr-pm` | Opus | Creates backlog from D&F docs; triages bugs; exclusive bug creator |
| `@paivot-pm` | Sonnet | PM-Acceptor -- evidence-based review of delivered work |
| `@paivot-developer` | Opus | Ephemeral -- implements one story, records proof, delivers |
| `@paivot-architect` | Opus | Designs system architecture, owns ARCHITECTURE.md |
| `@paivot-designer` | Opus | Captures user needs for all product types, owns DESIGN.md |
| `@paivot-business-analyst` | Opus | Iterative business discovery, owns BUSINESS.md |
| `@paivot-anchor` | Opus | Adversarial reviewer -- backlogs and milestones |
| `@paivot-retro` | Sonnet | Harvests learnings from completed epics |

## Commands

| Command | Description |
|---------|-------------|
| `/piv-init [prefix]` | Initialize git + nd + FSM + project structure |
| `/piv-loop [epic] [--all] [--max N]` | Unattended execution loop |
| `/piv-start` | Single execution pass |
| `/piv-cancel-loop` | Cancel active loop |
| `/piv-recover` | Recover from crash or inconsistent state |
| `/piv-retro` | Manual retrospective trigger |
| `/piv-code-review` | Comprehensive code audit |
| `/intake` | Capture feedback into backlog stories |
| `/vault-status` | Vault health check |
| `/vault-evolve` | Refine vault content from session experience |
| `/vault-capture` | Knowledge capture pass |
| `/vault-triage` | Review pending vault proposals |
| `/vault-settings` | Project settings management |

---

## Differences from paivot-graph (Claude Code)

| Aspect | paivot-graph (Claude Code) | paivot-opencode |
|--------|---------------------------|-----------------|
| Workflow enforcement | Go hooks (PreToolUse/PostToolUse/Stop) | nd FSM + AGENTS.md instructions |
| Agent refs | `paivot-graph:role` | `@paivot-role` |
| Model IDs | `opus`, `sonnet` | `anthropic/claude-opus-4-6-20250514` |
| Config format | `plugin.json` | `opencode.json` |
| Instructions file | `CLAUDE.md` | `AGENTS.md` |
| Agent mode | Implicit | Explicit `mode: subagent` |
| Loop control | `pvg hook stop` | Inline nd state checks |
| Git workflow | `beads-sync` trunk branch | `epic/<ID>-<Desc>` branch per epic |
| Issue tracker | `nd` (with label-based delivery) | `nd` (with FSM status-based delivery) |

---

## Development

```bash
make help            # Show all targets
make check-deps      # Verify pvg, vlt, nd, opencode installed
make test            # Run structural checks
make bump v=1.1.0    # Bump version
make fetch-vlt-skill # Install vlt skill (skip if present)
make update-vlt-skill # Force re-download vlt skill
```

## Acknowledgments

- **[Pivotal Labs](https://en.wikipedia.org/wiki/Pivotal_Labs)** (1989-2019) -- The methodology Paivot adapts
- **[Code Field](https://github.com/NeoVertex1/context-field/blob/main/code_field.md)** -- Cognitive conditions for better code
- **[Ralph Loop](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop)** -- Iterative execution pattern
- **[OpenCode](https://www.opencode.ai/)** -- Vendor-agnostic AI coding agent framework

## License

Apache 2.0
