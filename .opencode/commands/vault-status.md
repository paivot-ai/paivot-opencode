---
name: vault-status
description: Show Obsidian vault health -- note counts by folder, recent notes, pending proposals
---

# Vault Status

Show the current state and health of both the global Obsidian vault and the project-local vault.

**Global vault:** `vlt vault="Claude"` (resolves path dynamically)
**Project vault path:** `.vault/knowledge/` (relative to project root)

## Steps

1. **Check vault accessibility**:
   ```bash
   vlt vault="Claude" files total
   ```

2. **Gather global vault statistics**:
   ```bash
   vlt vault="Claude" files folder="methodology" total
   vlt vault="Claude" files folder="conventions" total
   vlt vault="Claude" files folder="decisions" total
   vlt vault="Claude" files folder="patterns" total
   vlt vault="Claude" files folder="debug" total
   vlt vault="Claude" files folder="concepts" total
   vlt vault="Claude" files folder="projects" total
   vlt vault="Claude" files folder="people" total
   vlt vault="Claude" files folder="_inbox" total
   ```

   Also check health:
   ```bash
   vlt vault="Claude" orphans
   vlt vault="Claude" unresolved
   ```

3. **Check project vault status**:
   ```bash
   test -d .vault/knowledge && echo "exists" || echo "not initialized"
   ```

   If it exists:
   ```bash
   vlt vault=".vault/knowledge" files folder="decisions" total
   vlt vault=".vault/knowledge" files folder="patterns" total
   vlt vault=".vault/knowledge" files folder="debug" total
   vlt vault=".vault/knowledge" files folder="conventions" total
   ```

4. **Check for actionable knowledge**:
   ```bash
   vlt vault=".vault/knowledge" search query="actionable: pending"
   ```

5. **Check for pending proposals**:
   ```bash
   vlt vault="Claude" search query="type: proposal"
   ```

6. **Present the report** as a formatted table with counts per folder, health metrics,
   actionable items, and pending proposals.

7. **Provide recommendations** based on findings.
