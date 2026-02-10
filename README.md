<p align="center">
  <img src="docs/paivot.png" alt="Paivot Logo" width="200">
</p>

# Paivot

**A structured software development methodology for AI coding agents, implemented for OpenCode.**

Paivot adapts the [Pivotal Labs methodology](docs/pivotal_methodology.md) -- the disciplined system of balanced teams, Discovery & Framing, and XP engineering practices that Pivotal Labs used to ship software for decades -- for a world where the builders are AI agents rather than human teams. [Read what changed and why.](docs/modified.md)

---

## Why Paivot?

AI coding agents are powerful but undisciplined. Left unconstrained, they:

- Skip testing or write superficial tests
- Build components in isolation that never integrate
- Lose context across sessions and make contradictory decisions
- Ignore business requirements in favor of technical novelty
- Mark work as "done" without proof it actually works

Paivot solves this by applying a proven software methodology (Pivotal) through specialized AI agents with strict role boundaries, enforced workflows, and hard quality gates. An external Finite State Machine implemented in Go controls the entire process, so the orchestrating LLM cannot "forget" or be "convinced" to skip steps.

The result: AI agents that follow a real development process -- Discovery & Framing before building, self-contained stories with embedded context, mandatory integration tests with real API calls, evidence-based code review, and continuous learning from completed work.

---

## Requirements

- [OpenCode](https://www.opencode.ai/) - Vendor-agnostic AI coding agent framework
- [beads](https://github.com/steveyegge/beads) - Git-backed issue tracker
- [Go](https://go.dev/dl/) 1.22+ (only needed to build the `piv` CLI for FSM enforcement)
- LLM provider API key (Anthropic, OpenAI, Google, or local models via Ollama)

## Installation

### 1. Install OpenCode

Follow the [OpenCode installation guide](https://docs.opencode.ai/installation) for your platform.

### 2. Install beads

```bash
# Download latest release for your platform
# Linux:
curl -sSL https://github.com/rneatherway/beads/releases/latest/download/bd-linux-amd64 -o /usr/local/bin/bd
chmod +x /usr/local/bin/bd

# macOS:
curl -sSL https://github.com/rneatherway/beads/releases/latest/download/bd-darwin-amd64 -o /usr/local/bin/bd
chmod +x /usr/local/bin/bd

# Windows:
# Download bd-windows-amd64.exe from releases and add to PATH
```

### 3. Configure LLM Provider

Paivot is vendor-agnostic. Configure your preferred provider in `opencode.json`:

**Anthropic (Claude):**
```bash
export ANTHROPIC_API_KEY='sk-ant-...'
```

**OpenAI (GPT-4):**
```bash
export OPENAI_API_KEY='sk-...'
```

**Google (Gemini):**
```bash
export GOOGLE_API_KEY='...'
```

**Local (Ollama):**
```bash
# Install Ollama first: https://ollama.ai
ollama pull qwen2.5-coder:32b
# No API key needed
```

### 4. Clone Paivot for OpenCode

```bash
git clone https://github.com/RamXX/paivot-opencode.git
cd paivot-opencode

# Copy agents and configuration to your project
cp -r .opencode ~/workspace/your-project/
cp opencode.json ~/workspace/your-project/
cp AGENTS.md ~/workspace/your-project/
cp -r docs ~/workspace/your-project/
```

### 5. Build the FSM CLI (Recommended)

The `piv` CLI provides hard enforcement of the workflow state machine. Without it, Paivot falls back to prompt-based orchestration (which works, but is less reliable for unattended operation).

Requires [Go](https://go.dev/dl/) 1.22+.

```bash
# Clone and build
git clone https://github.com/RamXX/paivot-claude.git /tmp/paivot-build
cd /tmp/paivot-build/piv-cli && make install
rm -rf /tmp/paivot-build
```

This installs the `piv` binary to `$(go env GOPATH)/bin/`. Make sure that directory is in your `PATH`.

Verify:

```bash
piv --help
```

---

## Quick Start

### New Project (Greenfield)

```bash
# In your project directory
cd ~/workspace/your-project
opencode

# Initialize everything (in OpenCode)
/piv-init

# Or with a custom issue prefix
/piv-init ABC
```

This initializes git, beads (with optional prefix), the FSM, and runs the quickstart guide. For empty projects, it automatically begins Discovery & Framing.

**Discovery & Framing (D&F)** produces three documents before any code is written:

1. Orchestrator spawns **@pivotal-business-analyst** -- captures business outcomes → `docs/BUSINESS.md`
2. Orchestrator spawns **@pivotal-designer** -- captures user needs and DX → `docs/DESIGN.md`
3. Orchestrator spawns **@pivotal-architect** -- defines technical approach → `docs/ARCHITECTURE.md`
4. Orchestrator spawns **@pivotal-sr-pm** -- creates the full backlog with ALL context embedded in each story
5. Orchestrator spawns **@pivotal-anchor** -- adversarially reviews the backlog for gaps
6. Execution begins only after Anchor approves

### Existing Project (Brownfield)

For existing codebases, you can skip full D&F and ask the orchestrator to create stories directly:

```
Create stories for implementing user authentication. We need login, logout, and password reset.
```

The orchestrator spawns @pivotal-sr-pm to create properly structured, self-contained stories from your description.

### Execution

```bash
# Start the execution phase (single pass)
/piv-start

# Or run unattended until complete or blocked
/piv-loop bd-a1b2              # Loop until specific epic is complete
/piv-loop --all                # Loop until entire backlog is complete
/piv-loop bd-a1b2 --max-iterations 100  # With custom limit (default: 50)
```

The orchestrator never writes code itself. It:
- Queries the FSM (`piv next`) to determine what to do
- Spawns **@pivotal-developer** agents for implementation
- Runs **verification** (`piv verify`) on delivered stories before PM review
- Spawns **@pivotal-pm** agents to review verified work
- Follows the FSM's priority order: verify first, then PM review, then rejected stories, then new work

Cancel anytime with `/piv-cancel-loop`.

---

## How It Works

### Architecture

Paivot uses a multi-agent architecture where each agent has a strict role and the orchestrator dispatches work:

```
                    +---------------------+
                    |    You (Human)      |
                    |  Business Owner     |
                    +---------------------+
                              |
                    Discovery & Framing
                              |
                              v
    +--------+  +----------+  +-----------+
    |   BA   |  | Designer |  | Architect |
    +--------+  +----------+  +-----------+
         \          |           /
          \         |          /
           v        v        v
         +-------------------+
         |      Sr. PM       |  Creates self-contained backlog
         +-------------------+
                   |
                   v
         +-------------------+
         |      Anchor       |  Adversarial review (approve/reject)
         +-------------------+
                   |
                   v
    +==============================+
    |    Orchestrator (Main LLM)   |     <--- Never writes code
    |    + FSM (piv CLI)           |     <--- Controls workflow
    +==============================+
           /              \
          v                v
    +-----------+    +-----------+
    | Developer |    |PM-Acceptor|
    | (ephemeral)|   | (ephemeral)|
    +-----------+    +-----------+
```

### The FSM: Why LLMs Need External Enforcement

LLMs don't reliably follow instructions. They can be "convinced" to deviate, "forget" rules after context compaction, and lose state across sessions. The `piv` CLI implements a Finite State Machine in Go that sits outside the LLM:

- **Hard enforcement**: A PreToolUse hook intercepts every agent spawn and blocks anything that doesn't match what the FSM recommends
- **Persistent state**: FSM state is in SQLite, not the LLM's context window -- it survives sessions and compaction
- **Audit trail**: Every state transition is recorded
- **Parallelization limits**: Enforced in code, not prompts

The orchestrator becomes a client of the FSM, not its owner. It calls `piv next` to find out what to do, does exactly that, records the event with `piv event`, and loops. If it tries to deviate, the hook blocks it.

See [docs/FSM-ORCHESTRATOR.md](docs/FSM-ORCHESTRATOR.md) for full FSM documentation including state diagrams.

### Story Delivery Workflow

Stories follow a strict delivery pipeline:

1. **Developer** implements the story and runs tests
2. **Developer** records proof in delivery notes (CI results, coverage, test output, commit SHA)
3. **Developer** marks story as `delivered` (NOT closed -- only PMs close stories)
4. **Verification gate** (`piv verify`) runs integration tests -- story cannot proceed to PM until tests pass
5. **PM-Acceptor** reviews using evidence-based approach (trusts developer proof unless suspicious)
6. **PM-Acceptor** either accepts (closes) or rejects (reopens with structured EXPECTED/DELIVERED/GAP/FIX notes)

Every rejection must include four parts: what was **expected**, what was **delivered**, where the **gap** is, and how to **fix** it. No vague feedback.

### Testing Philosophy

| Test Type | Purpose | Mocks OK? | Required For |
|-----------|---------|-----------|--------------|
| Unit | Code quality | Yes | 80% coverage |
| Integration | Real functionality | **No** | Every story |
| E2E | Full system works | **No** | Milestones |

**Integration tests with real API calls are mandatory.** A story cannot be delivered without them. Mocks in integration tests are an automatic rejection.

**Test scope is narrow by default.** Only tests affected by the story run. Full test suites run only when:
- Story explicitly requires `run-all-tests`
- Story is the final validation story before a milestone epic completes
- Story touches shared infrastructure

**Never soften tests.** If an external dependency breaks tests, BLOCK the story. Simplifying tests to pass masks the real issue.

### Learnings Lifecycle

Paivot captures and reuses knowledge as work progresses through a closed-loop system:

1. **Developers** record `LEARNINGS:` in delivery notes (gotchas, patterns, discoveries)
2. **PM-Acceptor** captures test gap learnings when bugs slip through -- labels stories with `contains-learnings`
3. **Retro agent** harvests learnings after milestone epics complete, writes insights to `.learnings/` directory
4. **Sr. PM is hard-gated**: After every retro, the FSM enters `LEARNINGS_REVIEW` and execution cannot resume until the Sr. PM has read the retro output and proactively updated all open stories in the backlog that could benefit from those insights
5. **Future work benefits** from accumulated knowledge embedded directly in story context

The full milestone flow (default):
```
MILESTONE_COMPLETE -> retro_started -> RETRO_RUNNING -> retro_complete -> LEARNINGS_REVIEW -> learnings_incorporated -> EXECUTING
```

With per-milestone decomposition (`piv config set decomposition per-milestone`), the flow extends:
```
LEARNINGS_REVIEW -> learnings_incorporated -> MILESTONE_DECOMPOSITION -> milestone_decomposed -> MILESTONE_ANCHOR_REVIEW -> milestone_stories_approved -> EXECUTING
```

In per-milestone mode, the Sr. PM creates all epics during D&F but only decomposes stories for the current milestone. After each milestone completes, the next milestone is decomposed with the benefit of accumulated learnings and implementation experience. This avoids waterfall planning while maintaining the structure AI agents need.

This compensates for the fact that AI agents cannot learn implicitly the way human teams do. Knowledge must be captured explicitly, stored persistently, and injected into future context deliberately. The hard gate ensures learnings are never written and forgotten -- they must be incorporated before work continues.

### Milestone Feedback

Milestones are natural checkpoints for user feedback:

- **Human-readable summaries**: When a milestone completes, the orchestrator outputs a plain-language summary of what was achieved
- **Async feedback**: Users can provide input anytime; Sr. PM assesses accumulated feedback at each milestone
- **Course correction**: Early milestones are especially valuable -- small adjustments prevent larger rework later
- **Unattended operation**: The process continues without blocking, but incorporates feedback when provided

---

## LLM Model Selection

Paivot is **vendor-agnostic** and works with any LLM provider. Configure in `opencode.json`:

```json
{
  "models": {
    "default": "anthropic/claude-sonnet-4-5-20250929",
    "opus": "anthropic/claude-opus-4-6-20250514",
    "sonnet": "anthropic/claude-sonnet-4-5-20250929",
    "haiku": "anthropic/claude-haiku-4-5-20251001",
    "openai-gpt4": "openai/gpt-4-turbo-2024-04-09",
    "openai-o1": "openai/o1-preview-2024-09-12",
    "google-gemini": "google/gemini-2.0-flash-exp",
    "groq-fast": "groq/llama-3.3-70b-versatile",
    "local-ollama": "ollama/qwen2.5-coder:32b"
  },
  "agent": {
    "pivotal-sr-pm": {
      "model": "{models.opus}"
    },
    "pivotal-developer": {
      "model": "{models.opus}"
    },
    "pivotal-pm": {
      "model": "{models.sonnet}"
    }
  }
}
```

### Supported Providers

| Provider | Models | Best For |
|----------|--------|----------|
| **Anthropic** | Claude Opus 4.6, Sonnet 4.5, Haiku 4.5 | Complex reasoning, code generation |
| **OpenAI** | GPT-4 Turbo, O1 Preview | Alternative for complex tasks |
| **Google** | Gemini 2.0 Flash | Google ecosystem integration |
| **Groq** | Llama 3.3 70B | Fast inference |
| **Ollama** | Qwen2.5-Coder, DeepSeek Coder | Privacy, cost control, local execution |
| **AWS Bedrock** | Claude, Llama, Mistral | AWS integration |
| **Azure OpenAI** | GPT-4, GPT-3.5 | Azure integration |

### Model Recommendations by Agent

| Agent | Recommended Model | Rationale |
|-------|------------------|-----------|
| Sr. PM | Opus / GPT-4 | Needs deep reasoning for backlog creation |
| Architect | Opus / GPT-4 | Complex system design decisions |
| Designer | Opus / GPT-4 | Understanding user needs requires nuance |
| Business Analyst | Opus / GPT-4 | Extracting business outcomes requires questioning |
| Anchor | Opus / GPT-4 | Adversarial review needs strong reasoning |
| Developer | Opus / GPT-4 / Sonnet | Code generation with quality standards |
| PM | Sonnet / GPT-3.5 | Evidence-based review, cost-effective |
| Retro | Sonnet / GPT-3.5 | Pattern extraction from completed work |

### Cost Optimization

```json
{
  "agent": {
    "pivotal-sr-pm": {
      "model": "{models.opus}"  // Complex reasoning
    },
    "pivotal-developer": {
      "model": "{models.sonnet}"  // Good balance
    },
    "pivotal-pm": {
      "model": "{models.haiku}"  // Simple review
    },
    "pivotal-retro": {
      "model": "{models.local-ollama}"  // Local inference
    }
  }
}
```

---

## Reference

### Commands

| Command | Description |
|---------|-------------|
| `/piv-init [prefix]` | Initialize project with git, beads, FSM, and D&F document structure |
| `/piv-start` | Start execution phase -- find ready work and dispatch agents |
| `/piv-loop [epic-id] [--all] [--max-iterations N]` | Start unattended execution loop until complete or blocked |
| `/piv-cancel-loop` | Cancel active execution loop |
| `/piv-recover` | Recover from crash or inconsistent state and resume execution |
| `/piv-code-review` | Comprehensive code audit (tests, mocks, modularity, security) |
| `/piv-retro` | Manually invoke a retrospective at any time |
| `/piv-config` | Configure parallelization settings (max developers, max PMs) |
| `/piv-enable` | Enable FSM enforcement for agent spawns |
| `/piv-disable` | Disable FSM enforcement for manual steering |

### Agents

Agents are invoked using `@agent-name` syntax:

| Agent | Model | Invocation | Role |
|-------|-------|------------|------|
| `pivotal-sr-pm` | Opus | `@pivotal-sr-pm "Create stories for..."` | Creates backlog from D&F documents; embeds ALL context into self-contained stories |
| `pivotal-pm` | Sonnet | `@pivotal-pm "Review story bd-a1b2"` | PM-Acceptor -- evidence-based review of delivered stories; files bugs |
| `pivotal-developer` | Opus | `@pivotal-developer "Implement bd-a1b2"` | Ephemeral -- implements one story, records proof of passing tests, delivers |
| `pivotal-architect` | Opus | `@pivotal-architect "Design system..."` | Designs system architecture, owns `docs/ARCHITECTURE.md` |
| `pivotal-designer` | Opus | `@pivotal-designer "Capture UX for..."` | Captures user needs and DX for all product types, owns `docs/DESIGN.md` |
| `pivotal-business-analyst` | Opus | `@pivotal-business-analyst "Conduct discovery"` | Captures business outcomes through iterative questioning, owns `docs/BUSINESS.md` |
| `pivotal-anchor` | Opus | `@pivotal-anchor "Review backlog"` | Adversarial reviewer -- reviews backlogs for gaps, validates milestones |
| `pivotal-retro` | Sonnet | `@pivotal-retro "Run retro for bd-a1b2"` | Harvests learnings from completed epics, writes actionable insights to `.learnings/` |

**Key constraint**: Agents cannot spawn subagents. Only the orchestrator (main OpenCode session) can spawn agents. This ensures a single point of coordination.

### Labels

| Label | Meaning |
|-------|---------|
| `delivered` | Developer done, awaiting verification |
| `verified` | Integration tests passed, ready for PM review |
| `verification-failed` | Integration tests failed, returned to developer |
| `accepted` | PM approved, story closed |
| `rejected` | PM failed AC, story reopened |
| `cant_fix` | 5+ rejections, needs human intervention |
| `milestone` | Epic with new demoable functionality |
| `tdd-strict` | Requires 100% unit test coverage |
| `run-all-tests` | Run full test suite, not narrow scope |
| `contains-learnings` | Story has LEARNINGS in notes (for retro filtering) |
| `ci-fix` | CI infrastructure fix in progress (lock) |
| `gap-fix` | Fixes gaps found by Anchor milestone review |

### Configuration

Configuration can be set in `opencode-paivot.local.md` (add to `.gitignore`) or via `/piv-config`:

```yaml
---
max_parallel_devs: 2   # Max Developer agents at once (default: 2)
max_parallel_pms: 1    # Max PM agents at once (default: 1)
decomposition: all-at-once  # or per-milestone
---
```

The FSM also supports configuration via CLI:

```bash
piv config set max_parallel_devs 3
piv config set max_parallel_pms 2
piv config set decomposition per-milestone  # Incremental backlog decomposition
piv config get
```

---

## Recovery

If a session crashes or state becomes inconsistent:

```bash
/piv-recover
```

This runs diagnostics on git and beads state, triages in-progress stories, commits any uncommitted recovery state, and resumes the execution loop. The orchestrator never runs tests or fixes code during recovery -- it spawns Developer agents for that.

You can also check FSM state directly:

```bash
piv status          # Human-readable
piv status --json   # Machine-readable
piv history --limit 10  # Recent transitions
```

---

## The Methodology

### Where It Comes From

Paivot is built on the [Pivotal Labs methodology](docs/pivotal_methodology.md) -- the system that Pivotal Labs (founded 1989, later Pivotal Software, acquired by VMware in 2019) used to deliver software across hundreds of client engagements. The core ideas:

- **Balanced Teams**: Product Management, Design, and Engineering work as peers, not in handoff chains
- **Discovery & Framing**: Understand the problem before building -- explicit, structured discovery rather than informal pre-work
- **XP Engineering Practices**: TDD, pairing, continuous integration, refactoring as ongoing work
- **Anchored Leadership**: Each discipline has a representative who asks hard questions and maintains quality
- **Iterative Delivery**: Short cycles with frequent demos and stakeholder feedback

### What Changed for AI

The core philosophy is unchanged -- outcomes first, discovery before building, quality enables speed. But the execution model changes significantly for AI agents. [Full details in the modifications document.](docs/modified.md)

Key adaptations:

| Original Pivotal | Paivot |
|-----------------|--------|
| Persistent human teams | Ephemeral agents, spawned per task |
| Pair programming | Orchestrated dispatch with PM review |
| Implicit shared context | Self-contained stories with ALL context embedded |
| Trust-based review | Evidence-based delivery with recorded proof |
| Pivotal Tracker | Beads (git-backed, CLI-first, AI-native) |
| Organic learning through pairing | Structured LEARNINGS captured in delivery notes |
| Flexible role boundaries | Strict role enforcement (agents lack judgment to flex) |
| Prompt-based reminders | External FSM in Go with hook-based enforcement |

### INVEST Stories and Parallel Execution

The INVEST criteria (Independent, Negotiable, Valuable, Estimable, Small, Testable) were always good practice in balanced-team methodologies. In Paivot, INVEST becomes structurally critical because **Independence enables parallelism**. When stories are truly independent -- touching different files, different components, no shared mutation -- the orchestrator can dispatch multiple Developer agents simultaneously.

Stories that violate Independence (two stories modifying the same gateway, the same handler, the same middleware) cause merge conflicts and compilation failures when worked on concurrently. The Sr. PM must verify file-scope independence during backlog creation, and the Anchor checks for it during review. Stories with overlapping file scopes require explicit `blocks` dependencies to force sequential execution.

### Git Workflow: Trunk-Based Development

**Paivot uses trunk-based development. No feature branches per story.**

Beads' hash-based IDs (`bd-a1b2`) eliminate merge collisions when multiple agents work concurrently on the same branch. The intelligent 3-way merge driver resolves field-level conflicts automatically. Feature branching defeats this architecture.

**Branch Structure:**
- `main` - Protected (requires PR for merges)
- `beads-sync` - Auto-managed sync branch where ALL agents commit
- Experimental branches only (rare, > 1 week work)

**Key Principle:** Stories are tracked in beads, NOT in git branches. The orchestrator dispatches multiple Developer agents who all commit to `beads-sync` concurrently. Hash-based IDs prevent collisions. Work accumulates on `beads-sync` and is merged to `main` periodically via PR (e.g., per milestone).

**Why this works:**
- Hash IDs (`bd-a1b2`) prevent ID collisions across agents
- Field-level 3-way merging resolves conflicts automatically
- Daemon auto-syncs beads state every 30 seconds
- No branch management overhead - agents focus on code
- Scales to 10+ concurrent agents effortlessly

**When NOT to branch:** Normal INVEST stories (< 2 days). Work on `beads-sync`.

**When TO branch:** Experiments (> 1 week, may discard). Requires `BEADS_NO_DAEMON=1` to disable auto-sync.

This is **prescriptive, not optional**. The system architecture assumes trunk-based development. See `docs/GIT_WORKFLOW.md` for full details.

### The "BLT" (Balanced Leadership Team)

During Discovery & Framing, three agents form the BLT -- each owns a document:

- **Business Analyst** -- owns `BUSINESS.md`: What are the business outcomes? What does success look like?
- **Designer** -- owns `DESIGN.md`: What do users need? What is the experience? (Applies to ALL products: UI, API, CLI, database)
- **Architect** -- owns `ARCHITECTURE.md`: How do we build it? What are the technical constraints?

After the BLT completes, the **Sr. PM** reads all three documents (catching cross-document conflicts and gaps), creates the backlog, and the **Anchor** adversarially reviews it. Execution begins only after the Anchor approves.

### Agent Roles Summary

| Task | Agent |
|------|-------|
| Capture business outcomes | Business Analyst |
| Design user experience (all product types) | Designer |
| Define system architecture | Architect |
| Create backlog with embedded context | Sr. PM |
| Adversarially review backlog / validate milestones | Anchor |
| Implement stories | Developer |
| Review deliveries (evidence-based) | PM-Acceptor (PM agent) |
| File bugs | PM agent (cheaper than Sr. PM) |
| Harvest learnings from completed epics | Retro |

---

## Code Review

Run a comprehensive audit at any time:

```bash
/piv-code-review
```

Checks for:
- Integration/E2E tests using real calls (flags mocks in integration tests)
- Silent non-implementations or stubs
- Backward compatibility cruft that should be removed
- Large files that could be modularized
- Security issues (even in dev)

Outputs to `/tmp/paivot-code-review-*.md` and offers to file bugs for findings.

---

## Project Structure

```
paivot-opencode/
  .opencode/
    agent/                  # Agent definitions (YAML frontmatter + markdown)
      pivotal-sr-pm.md
      pivotal-pm.md
      pivotal-developer.md
      pivotal-architect.md
      pivotal-designer.md
      pivotal-business-analyst.md
      pivotal-anchor.md
      pivotal-retro.md
    METHODOLOGY.md          # Full methodology (auto-loaded via opencode.json)
  opencode.json             # OpenCode configuration with models and agents
  AGENTS.md                 # Working agreement for AI agents
  docs/
    pivotal_methodology.md  # Original Pivotal methodology reference
    modified.md             # What changed for AI and why
    FSM-ORCHESTRATOR.md     # FSM architecture and state diagrams
    GIT_WORKFLOW.md         # Trunk-based development guide
    paivot.png              # Logo
  piv-cli/                  # Go CLI for FSM enforcement (shared with Claude Code)
    cmd/piv/main.go
    internal/               # FSM, engine, db, hook, dashboard packages
    Makefile
```

---

## OpenCode vs Claude Code

Paivot is implemented for both OpenCode and Claude Code. Key differences:

| Aspect | Claude Code | OpenCode |
|--------|-------------|----------|
| **Agent Invocation** | Skills auto-spawn | `@agent-name` syntax |
| **Configuration** | `.claude-plugin/plugin.json` | `opencode.json` |
| **Commands** | `/command-name` | `/command-name` |
| **Instructions** | `CLAUDE.md` | `AGENTS.md` |
| **Model Format** | `sonnet`, `opus` | `anthropic/claude-sonnet-4-5-20250929` |
| **Vendor Support** | Anthropic only | Any provider (Anthropic, OpenAI, Google, local) |
| **Agent Mode** | Implicit | Explicit `mode: subagent` |

OpenCode provides:
- **Vendor neutrality**: Use any LLM provider
- **Transparent pricing**: Mix providers for cost optimization
- **Local models**: Privacy and cost control
- **Cross-platform**: Windows, macOS, Linux

---

## Acknowledgments

Paivot incorporates ideas from:

- **[Pivotal Labs](https://en.wikipedia.org/wiki/Pivotal_Labs)** (1989-2019) -- The methodology that Paivot adapts. Founded by Rob Mee and Sherry Erskine, Pivotal Labs pioneered balanced teams, Discovery & Framing, and disciplined XP engineering practices. Their approach proved that speed comes from quality, not despite it.

- **[Code Field](https://github.com/NeoVertex1/context-field/blob/main/code_field.md)** -- A prompt engineering framework that creates cognitive conditions for better code by suppressing common LLM failure modes. The Developer agent's "Code Quality Mindset" section embeds Code Field principles: stating assumptions before writing code, asking "what would break this?", handling edge cases explicitly, and never claiming correctness without verification.

- **[Ralph Loop](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop)** -- An iterative execution pattern using a Stop hook to create self-referential feedback cycles within a single session. Paivot's `/piv-loop` command implements this technique for unattended execution.

- **[OpenCode](https://www.opencode.ai/)** -- A vendor-agnostic framework for AI coding agents that enables multi-provider support and local model execution. OpenCode's flexible architecture makes it possible to run Paivot with any LLM provider.

## License

MIT
