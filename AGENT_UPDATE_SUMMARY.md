# Agent Definition Update Summary

## Changes Made

Updated all agent definition files in `.opencode/agent/` to use trunk-based development workflow with the `beads-sync` branch.

## Files Updated

### pivotal-developer.md
- **Branch references**: Changed all `epic/<epic-id>` references to `beads-sync`
- **Commit workflow**: Updated to use trunk-based development
- **Push targets**: All commits now go to `origin/beads-sync`
- **Documentation**: Updated all code examples to reflect trunk-based workflow

### Key Changes
1. Spawning prompt: "Push to branch epic/<epic-id>" → "ALL commits go to beads-sync"
2. Git checkout: `git checkout epic/<epic-id>` → `git checkout beads-sync`
3. Git pull: `git pull origin epic/<epic-id>` → `git pull --rebase origin beads-sync`
4. Git push: `git push origin epic/<epic-id>` → `git push origin beads-sync`
5. Commit messages: All references to $BRANCH variable replaced with explicit `beads-sync`
6. Delivery notes: All commit SHAs now show `pushed to origin/beads-sync`

## Verification

All other agent files (PM, Sr PM, Architect, Designer, BA, Anchor, Retro) were checked:
- ✅ No epic branch references found
- ✅ Model references already vendor-agnostic (using OpenCode format)
- ✅ No Claude Code or Anthropic-specific terminology found

## Trunk-Based Development Benefits

1. **Simplified workflow**: Single branch for all development
2. **Better CI/CD**: All changes integrated continuously
3. **Reduced merge conflicts**: Smaller, more frequent integrations
4. **Cleaner history**: Linear git history on main development branch
5. **Easier collaboration**: All developers work on same branch

## Migration Path

For existing projects using epic branches:
1. Merge all epic branches to `beads-sync`
2. Update CI/CD to monitor `beads-sync` instead of `epic/*` branches
3. Train agents with updated agent definitions
4. Continue development on `beads-sync` only

## Next Steps

After merging this update:
1. All new stories will use trunk-based workflow
2. Developers will commit directly to `beads-sync`
3. Epic management happens via beads parent-child relationships, not git branches
4. Release process can branch from `beads-sync` when ready for production
