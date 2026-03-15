<p align="center">
  <img src="docs/paivot.png" alt="Paivot Logo" width="200">
</p>

# Paivot for OpenCode

**A structured software development methodology for AI coding agents, implemented for [OpenCode](https://www.opencode.ai/).**

Paivot adapts the [Pivotal Labs methodology](docs/pivotal_methodology.md) -- the disciplined system of balanced teams, Discovery & Framing, and XP engineering practices that Pivotal Labs used to ship software for decades -- for a world where the builders are AI agents rather than human teams.

This is the OpenCode port of [paivot-graph](https://github.com/paivot-ai/paivot-graph) (the Claude Code plugin). The core methodology is shared, but the enforcement model is adapted to OpenCode's architecture.

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

### nd FSM -- Base Workflow Enforcement

OpenCode does not have Claude Code's JSON hook system. Paivot therefore uses **nd's built-in finite state machine** for base status transitions, while the dispatcher enforces the higher-level delivery and merge choreography:

```
open --> in_progress --> delivered --> closed
                ^           |
                |           v
              rejected
```

Configuration (set by `/piv-init` through `pvg settings`):

```yaml
workflow.custom_statuses: "rejected"
workflow.sequence: "open,in_progress,closed"
workflow.exit_rules: "blocked:open,in_progress;rejected:in_progress"
workflow.fsm: true
```

nd rejects invalid base transitions at the CLI level. A developer cannot close a story directly, and a PM cannot close a story that has not progressed through `in_progress`. Delivery markers such as `delivered`, `accepted`, and `rejected` are still part of the Paivot contract and are enforced by dispatcher policy in OpenCode.

For multi-branch execution, the mutable nd backlog must be branch-independent.
Use a shared nd vault resolved from the repository's git common dir rather than
branch-local `.vault/issues/` copies.

Paivot standardizes on `pvg nd` so shared-backlog routing is structural rather than remembered.
Use it instead of bare `nd` whenever you are querying or mutating the live backlog.

### Dispatcher Pattern

When Paivot is invoked, the main OpenCode session becomes a **dispatcher** that:
- Asks `pvg` what should happen next (`pvg loop next --json`)
- Spawns specialized agents (`@paivot-developer`, `@paivot-pm`, etc.)
- Relays questions from agents to the user
- Uses `pvg story deliver|accept|reject` for tracker transitions instead of hand-managed label churn
- Never writes code, D&F documents, or stories itself

### Model Portability

OpenCode can run these prompts with Anthropic models or top OSS coding models. The workflow is more reliable when prompts stay structural:

- use exact marker blocks like `QUESTIONS_FOR_USER`, `BLT_ALIGNED`, `BLT_INCONSISTENCIES`, and `DISCOVERED_BUG`
- use `pvg nd` instead of relying on remembered `--vault` flags
- restate story id, phase, repo root, and expected output shape in every spawned prompt
- treat missing workflow state as blocking instead of guessing

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

## If Something Goes Wrong

Use the smallest escape hatch that solves the problem:

| Situation | What to run | What it does |
|-----------|-------------|--------------|
| Stop unattended execution | `/piv-cancel-loop` or `pvg loop cancel` | Cancels the active loop without deleting backlog or vault data |
| Recover after crash or context loss | `/piv-recover` or `pvg loop recover` | Cleans orphan worktrees, repairs loop state, and reports what remains |
| Inspect live tracker state safely | `pvg nd stats` | Reads the shared backlog instead of a branch-local copy |
| Remove Paivot from a project | `make uninstall TARGET=/path/to/project` | Removes `.opencode/`, `opencode.json`, and `AGENTS.md` from that project |

Your nd backlog and vault notes remain on disk. Cancelling a loop, recovering state, or uninstalling the OpenCode integration does not delete your work.

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
| Git workflow | `beads-sync` trunk branch | `main` + `story/<ID>` branches |
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
