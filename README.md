# Paivot Methodology for OpenCode

This directory contains the Paivot methodology ported to OpenCode as a drop-in replacement for Claude Code.

**Important**: See `.opencode/METHODOLOGY.md` for the complete methodology documentation including orchestrator rules, agent spawning, and the critical Backlog Review Gate.

## Setup

### 1. Set your Anthropic API Key

```bash
export ANTHROPIC_API_KEY='your-anthropic-api-key-here'
```

Or add to your shell profile (~/.zshrc or ~/.bashrc):

```bash
echo 'export ANTHROPIC_API_KEY="your-key"' >> ~/.zshrc
source ~/.zshrc
```

### 2. Verify the Installation

```bash
cd /tmp/paivot-opencode-test
./verify-agents.sh
```

### 3. Run OpenCode

```bash
cd /tmp/paivot-opencode-test
opencode
```

## Available Agents

All agents use `mode: subagent` and are invoked by the orchestrator (main agent).

| Agent | Model | Description |
|-------|-------|-------------|
| `pivotal-pm` | Sonnet | PM-Acceptor - reviews delivered stories with evidence-based acceptance/rejection |
| `pivotal-retro` | Sonnet | Retrospective agent - extracts learnings from completed milestone epics |
| `pivotal-developer` | Sonnet | Ephemeral developer - implements one story with proof of passing tests |
| `pivotal-anchor` | Opus | Adversarial backlog reviewer - finds gaps in walking skeletons, integration, D&F coverage |
| `pivotal-business-analyst` | Opus | Business Analyst - conducts iterative discovery, owns BUSINESS.md |
| `pivotal-designer` | Opus | Designer - UX advocate for all interfaces, owns DESIGN.md |
| `pivotal-sr-pm` | Opus | Senior PM - creates comprehensive initial backlog from D&F documents |
| `pivotal-architect` | Opus | Architect - designs system architecture, owns ARCHITECTURE.md |

## Using Agents

In OpenCode, you can invoke agents using the `--agent` flag:

```bash
# Start with a specific agent
opencode --agent pivotal-developer

# Or from within OpenCode TUI, use the agent command
/agent pivotal-developer "implement story bd-xxx"
```

## Key Differences from Claude Code

1. **Model format**: Models use `anthropic/claude-sonnet-4-20250514` format instead of `sonnet`
2. **No color field**: The `color` field is not supported in OpenCode
3. **No name field**: Agent name is derived from filename
4. **Mode field**: All agents specify `mode: subagent`
5. **Shorter descriptions**: OpenCode prefers concise 1-line descriptions

## Configuration

The `opencode.json` configures:
- Anthropic as the provider
- API key via environment variable
- Default model as Claude Sonnet

## File Structure

```
/tmp/paivot-opencode-test/
+-- opencode.json              # OpenCode configuration
+-- verify-agents.sh           # Verification script
+-- README.md                  # This file
+-- .opencode/
    +-- agent/
        +-- pivotal-pm.md
        +-- pivotal-retro.md
        +-- pivotal-anchor.md
        +-- pivotal-business-analyst.md
        +-- pivotal-designer.md
        +-- pivotal-sr-pm.md
        +-- pivotal-developer.md
        +-- pivotal-architect.md
```

## Troubleshooting

### "No agents found"

Make sure you are running OpenCode from the directory containing `.opencode/agent/`:

```bash
cd /tmp/paivot-opencode-test
opencode
```

### "API key not configured"

Set your Anthropic API key:

```bash
export ANTHROPIC_API_KEY='sk-ant-...'
```

### Agent not loading

Run the verification script to check frontmatter:

```bash
./verify-agents.sh
```

## Acknowledgments

Paivot incorporates ideas from:

- **[Code Field](https://github.com/NeoVertex1/context-field/blob/main/code_field.md)** - A prompt engineering framework that creates cognitive conditions for better code by suppressing common LLM failure modes. The Developer agent's "Code Quality Mindset" section embeds Code Field principles: stating assumptions before writing code, asking "what would break this?", handling edge cases explicitly, and never claiming correctness without verification.

- **[Ralph Loop](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop)** - An iterative execution pattern for self-referential feedback cycles within a single session. The Claude Code version of Paivot implements this as `/piv-loop` for unattended execution.
