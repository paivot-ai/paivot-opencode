---
name: piv-retro
description: Run retrospective manually
---

# Manual Retrospective

You are manually invoking a retrospective. This can be done at any point, not just after milestone completion.

## Determine Scope

Ask the user (or infer from context):

1. **Epic Retro** - Analyze a specific completed or in-progress epic
2. **Project Retro** - Analyze all accumulated learnings across the project
3. **Ad-hoc Retro** - Review recent work without a specific epic context

## Spawning the Retro Agent

### For Epic Retro

```
Invoke the agent:
@pivotal-retro "Run retrospective for epic bd-xxx. Extract learnings from all stories (completed and in-progress) and produce actionable insights."
```

### For Project Retro

```
Invoke the agent:
@pivotal-retro "Run FINAL PROJECT retrospective. Review all accumulated learnings in .learnings/ and identify systemic insights that transcend this project."
```

### For Ad-hoc Retro

```
Invoke the agent:
@pivotal-retro "Run ad-hoc retrospective. Review recent work and learnings. Focus on: <user's specific concern if any>. Extract patterns and produce actionable insights."
```

## When to Use Manual Retro

- **Mid-epic checkpoint** - Want to capture learnings before they're forgotten
- **After a difficult story** - Significant learnings that shouldn't wait
- **Before a pivot** - Capture what was learned before changing direction
- **Team sync point** - Want to share accumulated knowledge
- **Debugging session aftermath** - Hard-won knowledge to preserve

## Output

The retro agent will:
1. Extract and analyze learnings
2. Write insights to `.learnings/` directory
3. Report critical and important insights
4. Flag any backlog impact

## Quick Check First

Before spawning, verify there are learnings to harvest:

```bash
# Check for stories with LEARNINGS
bd list --status closed --json | jq -r '.[].notes' | grep -l "LEARNINGS:" || echo "No learnings found"

# Check existing learnings directory
ls -la .learnings/ 2>/dev/null || echo "No .learnings/ directory yet"
```

If no learnings exist yet, inform the user that there may not be much to analyze.
