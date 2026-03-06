PROJECT     := paivot-opencode
VERSION     := $(shell cat VERSION)

.PHONY: test check-deps check-pvg fetch-vlt-skill update-vlt-skill help bump

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Version management
# ---------------------------------------------------------------------------

bump: ## Bump version: make bump v=1.1.0
ifndef v
	$(error Usage: make bump v=X.Y.Z)
endif
	@echo "$(v)" > VERSION
	@echo "Version bumped to $(v)"

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

check-deps: ## Verify required dependencies are installed
	@command -v pvg >/dev/null 2>&1 || \
		(echo "WARN: pvg is not installed." && \
		 echo "      Install from https://github.com/paivot-ai/pvg" && \
		 echo "      gh release download -R paivot-ai/pvg -p '*darwin*arm64*' -D /tmp && tar xzf /tmp/pvg_*.tar.gz -C ~/go/bin")
	@command -v pvg >/dev/null 2>&1 && echo "OK: pvg $$(pvg version 2>&1)" || true
	@command -v vlt >/dev/null 2>&1 || \
		(echo "ERROR: vlt is not installed." && \
		 echo "       Install from https://github.com/RamXX/vlt" && \
		 echo "       git clone https://github.com/RamXX/vlt.git && cd vlt && make install" && \
		 exit 1)
	@echo "OK: vlt $$(vlt version 2>&1)"
	@command -v nd >/dev/null 2>&1 && \
		echo "OK: nd found at $$(command -v nd)" || \
		echo "WARN: nd not installed (needed for execution agents -- install from https://github.com/RamXX/nd)"
	@command -v opencode >/dev/null 2>&1 || \
		(echo "ERROR: opencode is not installed." && exit 1)
	@echo "OK: opencode found"

check-pvg: ## Verify pvg is on PATH
	@command -v pvg >/dev/null 2>&1 || \
		(echo "ERROR: pvg is not on PATH." && \
		 echo "       Install from https://github.com/paivot-ai/pvg" && \
		 exit 1)
	@echo "OK: pvg found at $$(command -v pvg) -- $$(pvg version 2>&1)"

# ---------------------------------------------------------------------------
# vlt skill management
# ---------------------------------------------------------------------------

fetch-vlt-skill: ## Fetch and install the vlt skill from GitHub (skips if present)
	scripts/fetch-vlt-skill.sh

update-vlt-skill: ## Force-update the vlt skill from GitHub
	scripts/fetch-vlt-skill.sh --force

# ---------------------------------------------------------------------------
# Lint & test
# ---------------------------------------------------------------------------

test: check-deps ## Run all checks
	@echo "--- Structural checks ---"
	@echo ""
	@echo "Checking opencode.json is valid JSON..."
	@python3 -c "import json; json.load(open('opencode.json'))" || (echo "FAIL: opencode.json is not valid JSON" && exit 1)
	@echo "OK: opencode.json is valid JSON"
	@echo ""
	@echo "Checking all 8 agent files exist..."
	@for agent in sr-pm pm developer architect designer business-analyst anchor retro; do \
		test -f .opencode/agent/paivot-$$agent.md || (echo "FAIL: .opencode/agent/paivot-$$agent.md not found" && exit 1); \
	done
	@echo "OK: All 8 agent files present"
	@echo ""
	@echo "Checking agent frontmatter has mode: subagent..."
	@for agent in sr-pm pm developer architect designer business-analyst anchor retro; do \
		grep -q 'mode: subagent' .opencode/agent/paivot-$$agent.md || (echo "FAIL: paivot-$$agent.md missing mode: subagent" && exit 1); \
	done
	@echo "OK: All agents have mode: subagent"
	@echo ""
	@echo "Checking agent model IDs are valid..."
	@for agent in sr-pm pm developer architect designer business-analyst anchor retro; do \
		grep -qE 'model: anthropic/claude-(opus|sonnet|haiku)' .opencode/agent/paivot-$$agent.md || (echo "FAIL: paivot-$$agent.md has invalid model ID" && exit 1); \
	done
	@echo "OK: All agents have valid model IDs"
	@echo ""
	@echo "Checking vault loaders use vlt commands..."
	@for agent in sr-pm developer anchor retro; do \
		grep -q 'vlt vault="Claude" read file=' .opencode/agent/paivot-$$agent.md || (echo "FAIL: paivot-$$agent.md missing vlt read command" && exit 1); \
	done
	@echo "OK: Vault-backed agents use dynamic vlt commands"
	@echo ""
	@echo "Checking all command files have name and description..."
	@for cmd in .opencode/commands/*.md; do \
		grep -q 'description:' "$$cmd" || (echo "FAIL: $$cmd missing description" && exit 1); \
	done
	@echo "OK: All commands have description"
	@echo ""
	@echo "Checking skill files have name and version..."
	@for skill in .opencode/skills/*/SKILL.md; do \
		grep -q 'name:' "$$skill" || (echo "FAIL: $$skill missing name" && exit 1); \
		grep -q 'version:' "$$skill" || (echo "FAIL: $$skill missing version" && exit 1); \
	done
	@echo "OK: All skills have name and version"
	@echo ""
	@echo "Checking no stale references remain..."
	@if grep -rq 'piv next\|piv event\|beads-sync\|piv config\|paivot-graph:' .opencode/ AGENTS.md 2>/dev/null; then \
		echo "FAIL: Stale references found:"; \
		grep -rn 'piv next\|piv event\|beads-sync\|piv config\|paivot-graph:' .opencode/ AGENTS.md 2>/dev/null; \
		exit 1; \
	fi
	@echo "OK: No stale references"
	@echo ""
	@echo "Checking no bd command references..."
	@if grep -rqP '\bbd\s+(init|list|show|sync|ready|close|update|label|search|quickstart)\b' .opencode/ AGENTS.md 2>/dev/null; then \
		echo "FAIL: Old bd command references found"; \
		exit 1; \
	fi
	@echo "OK: No old bd command references"
	@echo ""
	@echo "Checking scripts are executable..."
	@test -x scripts/fetch-vlt-skill.sh || (echo "FAIL: fetch-vlt-skill.sh not executable" && exit 1)
	@echo "OK: All scripts are executable"
	@echo ""
	@echo "All checks passed."
