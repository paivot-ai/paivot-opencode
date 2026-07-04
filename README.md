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
| [nd](https://github.com/paivot-ai/nd) | Git-native issue tracker with FSM | `git clone && make install` |
| [pvg](https://github.com/paivot-ai/pvg) | Loop lifecycle and guard CLI | `gh release download -R paivot-ai/pvg` |
| [vlt](https://github.com/paivot-ai/vlt) | Vault CLI for knowledge management | `git clone && make install` |
| [machinery](https://github.com/RamXX/machinery) | Design substrate behind `design.machinery`: domain model, C4 contract, state machines, oracles, and the deterministic gates `pvg gates`/`pvg rtm`/`pvg story approve-red` shell out to | `pvg update` installs the binary; `machinery install --home ~/.agents` places its skill |
| LLM API key | Anthropic recommended (Opus/Sonnet) | Provider-specific |

Strongly recommended:

| Tool | Purpose | Install |
|------|---------|---------|
| Codebase indexing MCP | API signature verification, cross-cutting concern discovery | See below |

A codebase indexing MCP server dramatically improves story quality. When available, Paivot agents use it for API signature verification, cross-cutting concern discovery, and module count validation instead of grep. This prevents the most common class of Anchor rejections: hallucinated API signatures.

Any MCP server that provides `search_graph`, `get_code_snippet`, and `trace_call_path` works. Two tested options:

- **[codebase-memory-mcp](https://github.com/nicobailon/codebase-memory-mcp)** -- Graph-based indexing with Cypher queries, call path tracing, and architecture summaries
- **[Augment Code](https://www.augmentcode.com/)** (cx) -- Commercial codebase intelligence with similar capabilities

Configure via your OpenCode MCP settings or project-level MCP config. After indexing, agents automatically prefer MCP tools over grep for codebase queries.

Without a codebase indexing server, agents fall back to grep/ripgrep. This works but is slower, less precise on call graph analysis, and cannot verify module counts as reliably.

Optional:
- [Go](https://go.dev/dl/) 1.24+ -- only needed if you want to build `pvg` from source instead of using its release binaries

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/paivot-ai/paivot-opencode.git
cd paivot-opencode

# 2. Verify dependencies and install global agents/skills
make check-deps
make install

# 3. Install the project-local OpenCode surface
make install-project TARGET=/path/to/your-project

# 4. Initialize in your project
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

The shared live vault is not part of git history, so durability comes from
snapshots: at each epic completion gate the dispatcher runs `pvg nd sync` to
export the backlog into a tracked `.vault/backlog-snapshot/` and commits it on
main. After a fresh clone, `pvg nd restore` re-imports the snapshot into an
empty live vault.

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

OpenCode can run these prompts with Anthropic models or top OSS coding models. The model is configured as a **single top-level `model` default** in `opencode.json` -- agents do not pin their own models (no `model:` in agent frontmatter, no per-agent `model` in `opencode.json`). To switch providers or models, change that one key, or override it per project in the project's `opencode.json`. The shipped default is `github-copilot/gpt-5.5`.

The workflow is more reliable when prompts stay structural:

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

### Self-Contained Agent Prompts

Agent prompts are **self-contained** in their `.md` files -- no runtime vault dependency. The vault is used for learned knowledge (decisions, patterns, debug insights) that agents can consult, not for operational instructions they must obey.

---

## Agents

All agents run on the single top-level `model` default (see Model Portability above).

| Agent | Role |
|-------|------|
| `@paivot-sr-pm` | Creates backlog from D&F docs; triages bugs; exclusive bug creator |
| `@paivot-pm` | PM-Acceptor -- evidence-based review of delivered work |
| `@paivot-developer` | Ephemeral -- implements one story, records proof, delivers |
| `@paivot-architect` | Designs system architecture, owns ARCHITECTURE.md |
| `@paivot-designer` | Captures user needs for all product types, owns DESIGN.md |
| `@paivot-business-analyst` | Iterative business discovery, owns BUSINESS.md |
| `@paivot-ba-challenger` | Adversarial review of BUSINESS.md (opt-in via `dnf.specialist_review`) |
| `@paivot-designer-challenger` | Adversarial review of DESIGN.md (opt-in via `dnf.specialist_review`) |
| `@paivot-architect-challenger` | Adversarial review of ARCHITECTURE.md (opt-in via `dnf.specialist_review`) |
| `@paivot-anchor` | Adversarial reviewer -- backlogs and milestones |
| `@paivot-retro` | Harvests learnings from completed epics |

## Execution Workflow

The execution loop (`/piv-loop`) drives stories through development, review, and delivery. Two structural gates enforce quality:

**Story gate:** Every story must have passing integration tests with no mocks before the PM-Acceptor will accept it. Tests gated behind env vars or skipped tests are rejected on sight.

**Epic gate:** After all stories in an epic are accepted and merged to the epic branch, three steps run before the epic reaches main:

1. **E2e verification** -- the full test suite (unit + integration + e2e) runs on the merged epic branch. No epic is done without passing e2e tests.
2. **Anchor milestone review** -- the Anchor agent validates real delivery: no mocks in integration tests, boundary maps satisfied, skills consulted.
3. **Merge to main** -- depends on `workflow.solo_dev` setting:
   - `true` (default): merge directly to main, push, delete epic and story branches
   - `false`: create a PR for team review
4. **Snapshot + retro** -- the dispatcher exports the backlog (`pvg nd sync`) and
   commits `.vault/backlog-snapshot/` on main, then spawns the retro agent and
   commits its `.vault/knowledge/` notes.

Configure with: `pvg settings workflow.solo_dev=false` for team workflows.

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

## Convention: Paivot projects do not use a project-level `CLAUDE.md`

A Paivot-managed project (any directory containing `.vault/issues/` or `.paivot/config.yaml`) deliberately has **no** project-level `CLAUDE.md`. The methodology lives in the host repo's `AGENTS.md` (paivot-opencode is one such host); project-specific hard rules live as `scope: project` notes under `.vault/knowledge/conventions/`. A parallel `CLAUDE.md` would create two competing sources and rule duplication.

If you want to record a project-specific hard rule (e.g., "no skip-if-missing integration tests", "all migrations must be reversible"), write it as a `scope: project` note under `.vault/knowledge/conventions/`. The Sr PM's Phase 1 hard-rule ingestion (in `@paivot-sr-pm`) reads those notes automatically -- alongside the project `AGENTS.md` and your user global `~/.claude/CLAUDE.md` -- and feeds them into the Anchor's Master Checklist quality gates.

Recommended one-liner to add to your user global `~/.claude/CLAUDE.md` so any session in any directory honors this convention:

> **Paivot project detection.** If the working directory or any ancestor contains `.vault/issues/` or `.paivot/config.yaml`, treat it as a Paivot-managed project: do not create or expect a project-level `CLAUDE.md`. Project-specific conventions live under `.vault/knowledge/conventions/`; methodology lives in the Paivot vault and in the host repo's `AGENTS.md`; workflow is governed by the agent prompts (paivot-graph for Claude Code, paivot-codex for Codex, paivot-opencode for OpenCode). Hard rules that would normally live in a project `CLAUDE.md` belong as `scope: project` vault notes instead.

---

## Differences from paivot-graph (Claude Code)

| Aspect | paivot-graph (Claude Code) | paivot-opencode |
|--------|---------------------------|-----------------|
| Workflow enforcement | Claude hooks plus shared `pvg` guard/loop commands | OpenCode commands/prompts plus the same shared `pvg` control plane |
| Agent refs | `paivot-graph:role` | `@paivot-role` |
| Model IDs | `opus`, `sonnet` per agent | single top-level `model` default (no per-agent pins) |
| Config format | `plugin.json` | `opencode.json` |
| Instructions file | `CLAUDE.md` | `AGENTS.md` |
| Agent mode | Implicit | Explicit `mode: subagent` |
| Loop control | Claude hook lifecycle plus `pvg loop ...` | OpenCode commands plus `pvg loop ...` |
| Git workflow | `beads-sync` trunk branch | `main` + `story/<ID>` branches |
| Issue tracker | `nd` via `pvg nd` shared live vault | `nd` via `pvg nd` shared live vault |

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
