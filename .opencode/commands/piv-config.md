---
name: piv-config
description: Configure parallelization settings
---

# Paivot Configuration

This command helps you configure Paivot settings for the current project.

## Current Configuration

First, check if configuration exists:

```bash
if [ -f ".opencode/paivot.local.md" ]; then
    echo "Current configuration:"
    cat .opencode/paivot.local.md
else
    echo "No configuration file. Using defaults: max_parallel_devs=2, max_parallel_pms=1"
fi
```

## Configuration Options

| Setting | Default | Description |
|---------|---------|-------------|
| `max_parallel_devs` | 2 | Maximum Developer agents that can run concurrently |
| `max_parallel_pms` | 1 | Maximum PM-Acceptor agents that can run concurrently |

## Interactive Setup

Ask the user what limits they want:

1. **max_parallel_devs** - How many Developer agents can run at once?
   - Options: 1 (sequential), 2 (moderate), 3-4 (parallel), 6+ (aggressive)
   - Consider: heavy compilation, LLM calls, memory usage

2. **max_parallel_pms** - How many PM agents can run at once?
   - Options: 1 (sequential - recommended), 2 (parallel)
   - PM work is usually lighter than dev work

## Create/Update Configuration

After getting user input, create or update the configuration file:

```bash
mkdir -p .opencode

cat > .opencode/paivot.local.md << 'EOF'
---
max_parallel_devs: <USER_VALUE>
max_parallel_pms: <USER_VALUE>
---

# Paivot Configuration

Project-specific settings for the Paivot plugin.

## Settings

- **max_parallel_devs**: Maximum Developer agents running concurrently
- **max_parallel_pms**: Maximum PM-Acceptor agents running concurrently

## Notes

- Lower values are safer for resource-constrained machines
- Higher values speed up execution but may overwhelm the system
- Adjust based on your workload (LLM calls, compilation, etc.)
EOF
```

## Gitignore

Ensure the config file is gitignored (it's user-specific):

```bash
if ! grep -q "\.opencode/\*\.local\.md" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Paivot local config" >> .gitignore
    echo ".opencode/*.local.md" >> .gitignore
    echo "Added .opencode/*.local.md to .gitignore"
fi
```

## Confirmation

After creating the config, confirm to the user:

```
Configuration saved to .opencode/paivot.local.md

Settings:
- max_parallel_devs: <value>
- max_parallel_pms: <value>

These limits will be respected by /piv-loop, /piv-start, and /piv-recover.
```
