#!/bin/bash
# Verify Paivot agents are valid and recognized by OpenCode
# Usage: ./verify-agents.sh

set -e

AGENT_DIR=".opencode/agent"
EXPECTED_AGENTS=(
    "pivotal-pm"
    "pivotal-retro"
    "pivotal-anchor"
    "pivotal-business-analyst"
    "pivotal-designer"
    "pivotal-sr-pm"
    "pivotal-developer"
    "pivotal-architect"
)

echo "=== Paivot Agent Verification ==="
echo ""

# Check agent directory exists
if [ ! -d "$AGENT_DIR" ]; then
    echo "ERROR: Agent directory $AGENT_DIR not found"
    exit 1
fi

echo "1. Checking agent files exist..."
missing=0
for agent in "${EXPECTED_AGENTS[@]}"; do
    file="$AGENT_DIR/${agent}.md"
    if [ -f "$file" ]; then
        echo "   [OK] $agent"
    else
        echo "   [MISSING] $agent"
        missing=$((missing + 1))
    fi
done
echo ""

if [ $missing -gt 0 ]; then
    echo "ERROR: $missing agent(s) missing"
    exit 1
fi

echo "2. Validating YAML frontmatter format..."
errors=0
for agent in "${EXPECTED_AGENTS[@]}"; do
    file="$AGENT_DIR/${agent}.md"

    # Check for required frontmatter fields
    if ! head -20 "$file" | grep -q "^description:"; then
        echo "   [ERROR] $agent: missing 'description' field"
        errors=$((errors + 1))
    fi

    if ! head -20 "$file" | grep -q "^mode:"; then
        echo "   [ERROR] $agent: missing 'mode' field"
        errors=$((errors + 1))
    fi

    if ! head -20 "$file" | grep -q "^model:"; then
        echo "   [ERROR] $agent: missing 'model' field"
        errors=$((errors + 1))
    fi

    # Check for deprecated fields that should NOT be present
    if head -20 "$file" | grep -q "^color:"; then
        echo "   [WARN] $agent: 'color' field present (not supported in OpenCode)"
    fi

    if head -20 "$file" | grep -q "^name:"; then
        echo "   [WARN] $agent: 'name' field present (not needed in OpenCode)"
    fi

    # Check model format
    model=$(head -20 "$file" | grep "^model:" | sed 's/model: *//')
    if [[ "$model" != anthropic/* ]]; then
        echo "   [ERROR] $agent: model '$model' should be 'anthropic/claude-*'"
        errors=$((errors + 1))
    else
        echo "   [OK] $agent: model=$model"
    fi
done
echo ""

if [ $errors -gt 0 ]; then
    echo "ERROR: $errors validation error(s) found"
    exit 1
fi

echo "3. Checking opencode.json configuration..."
if [ -f "opencode.json" ]; then
    echo "   [OK] opencode.json exists"

    # Check for required fields
    if grep -q '"anthropic"' opencode.json; then
        echo "   [OK] Anthropic provider configured"
    else
        echo "   [ERROR] Anthropic provider not configured"
        errors=$((errors + 1))
    fi

    if grep -q 'ANTHROPIC_API_KEY' opencode.json; then
        echo "   [OK] API key placeholder found"
    else
        echo "   [ERROR] API key configuration missing"
        errors=$((errors + 1))
    fi
else
    echo "   [ERROR] opencode.json not found"
    errors=$((errors + 1))
fi
echo ""

echo "4. Listing agents via OpenCode CLI..."
echo "   (requires ANTHROPIC_API_KEY to be set)"
if [ -n "$ANTHROPIC_API_KEY" ]; then
    cd "$(dirname "$0")"
    opencode agent list 2>&1 | head -50 || echo "   [WARN] Could not list agents"
else
    echo "   [SKIP] ANTHROPIC_API_KEY not set"
fi
echo ""

echo "=== Summary ==="
echo "Total agents: ${#EXPECTED_AGENTS[@]}"
echo "Agents found: $((${#EXPECTED_AGENTS[@]} - missing))"

if [ $errors -eq 0 ] && [ $missing -eq 0 ]; then
    echo ""
    echo "SUCCESS: All agents validated"
    echo ""
    echo "Next steps:"
    echo "  1. Set ANTHROPIC_API_KEY: export ANTHROPIC_API_KEY='your-key'"
    echo "  2. Run OpenCode: cd $(pwd) && opencode"
    echo "  3. Use agents with: /agent pivotal-developer 'implement story bd-xxx'"
    exit 0
else
    echo ""
    echo "FAILED: Some validations failed"
    exit 1
fi
