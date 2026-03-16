PROJECT     := paivot-opencode
VERSION     := $(shell cat VERSION)
PLUGIN_DIR  := $(shell pwd)
OC_CONFIG   := $(HOME)/.config/opencode
OC_AGENTS   := sr-pm pm developer architect designer business-analyst anchor retro ba-challenger designer-challenger architect-challenger

.PHONY: install install-project update uninstall test check-deps check-pvg fetch-vlt-skill update-vlt-skill help bump

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
		 echo "       Install from https://github.com/paivot-ai/vlt" && \
		 echo "       git clone https://github.com/paivot-ai/vlt.git && cd vlt && make install" && \
		 exit 1)
	@echo "OK: vlt $$(vlt version 2>&1)"
	@command -v nd >/dev/null 2>&1 && \
		echo "OK: nd found at $$(command -v nd)" || \
		echo "WARN: nd not installed (needed for execution agents -- install from https://github.com/paivot-ai/nd)"
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
# Install / update / uninstall
# ---------------------------------------------------------------------------

install: check-deps fetch-vlt-skill ## Install Paivot agents and skills globally into ~/.config/opencode
	@echo "Installing Paivot into $(OC_CONFIG)..."
	@bash -euo pipefail -c '\
	  copy_dir() { \
	    local src="$$1" dst="$$2"; \
	    mkdir -p "$$dst"; \
	    if command -v rsync >/dev/null 2>&1; then \
	      rsync -a --delete "$$src/" "$$dst/"; \
	    else \
	      rm -rf "$$dst"/*; \
	      cp -R "$$src"/. "$$dst/"; \
	    fi; \
	  }; \
	  \
	  mkdir -p "$(OC_CONFIG)/agent" "$(OC_CONFIG)/skills"; \
	  \
	  for agent in $(OC_AGENTS); do \
	    install -m 0600 "$(PLUGIN_DIR)/.opencode/agent/paivot-$$agent.md" \
	      "$(OC_CONFIG)/agent/paivot-$$agent.md"; \
	  done; \
	  echo "  agents/ synced ($(words $(OC_AGENTS)) agents)"; \
	  \
	  for skill_dir in "$(PLUGIN_DIR)/.opencode/skills"/*/; do \
	    skill_name=$$(basename "$$skill_dir"); \
	    copy_dir "$$skill_dir" "$(OC_CONFIG)/skills/$$skill_name"; \
	  done; \
	  echo "  skills/ synced"; \
	  \
	  install -m 0644 "$(PLUGIN_DIR)/AGENTS.md" "$(OC_CONFIG)/AGENTS.md"; \
	  echo "  AGENTS.md installed"; \
	  \
	  echo ""; \
	  echo "Install complete (v$(VERSION))."; \
	  echo "Agent prompts and skills are now available globally."; \
	  echo "NOTE: Agent entries in ~/.config/opencode/opencode.json are user-managed"; \
	  echo "      (provider, model, and permission overrides)."; \
	'

update: check-deps update-vlt-skill ## Update global Paivot install
	@test -d "$(OC_CONFIG)/agent" || (echo "ERROR: Paivot not installed -- run 'make install' first" && exit 1)
	@$(MAKE) --no-print-directory install
	@echo "Update complete (v$(VERSION))."

install-project: check-deps fetch-vlt-skill ## Install Paivot into a specific project: make install-project TARGET=/path/to/project
ifndef TARGET
	$(error Usage: make install-project TARGET=/path/to/project)
endif
	@test -d "$(TARGET)" || (echo "ERROR: $(TARGET) does not exist" && exit 1)
	@echo "Installing Paivot OpenCode config into $(TARGET)..."
	@bash -euo pipefail -c '\
	  copy_dir() { \
	    local src="$$1" dst="$$2"; \
	    mkdir -p "$$dst"; \
	    if command -v rsync >/dev/null 2>&1; then \
	      rsync -a --delete "$$src/" "$$dst/"; \
	    else \
	      rm -rf "$$dst"/*; \
	      cp -R "$$src"/. "$$dst/"; \
	    fi; \
	  }; \
	  \
	  copy_dir "$(PLUGIN_DIR)/.opencode" "$(TARGET)/.opencode"; \
	  echo "  .opencode/ synced"; \
	  \
	  install -m 0644 "$(PLUGIN_DIR)/opencode.json" "$(TARGET)/opencode.json"; \
	  echo "  opencode.json installed"; \
	  \
	  install -m 0644 "$(PLUGIN_DIR)/AGENTS.md" "$(TARGET)/AGENTS.md"; \
	  echo "  AGENTS.md installed"; \
	  \
	  echo ""; \
	  echo "Project install complete (v$(VERSION))."; \
	  echo "Run opencode in $(TARGET) to use Paivot."; \
	'

uninstall: ## Remove Paivot globally or from a project (optional TARGET=/path/to/project)
ifdef TARGET
	@test -d "$(TARGET)/.opencode" || (echo "Nothing to uninstall in $(TARGET)" && exit 0)
	@echo "Removing Paivot OpenCode config from $(TARGET)..."
	@rm -rf "$(TARGET)/.opencode"
	@rm -f "$(TARGET)/opencode.json"
	@rm -f "$(TARGET)/AGENTS.md"
	@echo "Paivot removed from $(TARGET)."
else
	@echo "Removing Paivot from $(OC_CONFIG)..."
	@for agent in $(OC_AGENTS); do \
		rm -f "$(OC_CONFIG)/agent/paivot-$$agent.md"; \
	done
	@rm -rf "$(OC_CONFIG)/skills/c4" "$(OC_CONFIG)/skills/vault-knowledge"
	@rm -rf "$(OC_CONFIG)/skills/paivot-methodology" "$(OC_CONFIG)/skills/paivot-orchestrator"
	@rm -f "$(OC_CONFIG)/AGENTS.md"
	@echo "Paivot removed."
endif

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
	@echo "Checking all 11 agent files exist..."
	@for agent in sr-pm pm developer architect designer business-analyst anchor retro ba-challenger designer-challenger architect-challenger; do \
		test -f .opencode/agent/paivot-$$agent.md || (echo "FAIL: .opencode/agent/paivot-$$agent.md not found" && exit 1); \
	done
	@echo "OK: All 11 agent files present"
	@echo ""
	@echo "Checking agent frontmatter has mode: subagent..."
	@for agent in sr-pm pm developer architect designer business-analyst anchor retro ba-challenger designer-challenger architect-challenger; do \
		grep -q 'mode: subagent' .opencode/agent/paivot-$$agent.md || (echo "FAIL: paivot-$$agent.md missing mode: subagent" && exit 1); \
	done
	@echo "OK: All agents have mode: subagent"
	@echo ""
	@echo "Checking agent model fields are present..."
	@for agent in sr-pm pm developer architect designer business-analyst anchor retro ba-challenger designer-challenger architect-challenger; do \
		grep -q '^model: ' .opencode/agent/paivot-$$agent.md || (echo "FAIL: paivot-$$agent.md missing model field" && exit 1); \
	done
	@echo "OK: All agents declare a model field"
	@echo ""
	@echo "Checking vault loaders use vlt commands..."
	@for agent in sr-pm developer anchor retro; do \
		grep -q 'vlt vault="Claude" read file=' .opencode/agent/paivot-$$agent.md || (echo "FAIL: paivot-$$agent.md missing vlt read command" && exit 1); \
	done
	@echo "OK: Vault-backed agents use dynamic vlt commands"
	@echo ""
	@echo "Checking pvg shared workflow commands are available..."
	@pvg nd root --ensure >/dev/null || (echo "FAIL: pvg nd root --ensure failed" && exit 1)
	@pvg help 2>&1 | grep -q 'story <subcommand>' || (echo "FAIL: installed pvg is missing story workflow commands" && exit 1)
	@pvg help 2>&1 | grep -q 'loop setup' || (echo "FAIL: installed pvg is missing loop workflow commands" && exit 1)
	@pvg loop next --json >/dev/null || (echo "FAIL: pvg loop next --json failed" && exit 1)
	@echo "OK: Shared pvg workflow commands available"
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
	@echo "Checking workflow settings docs use workflow.* keys..."
	@if grep -rq '^status\.\(custom\|sequence\|exit_rules\|fsm\):' AGENTS.md README.md .opencode/commands 2>/dev/null; then \
		echo "FAIL: Stale status.* workflow keys found"; \
		exit 1; \
	fi
	@echo "OK: Workflow settings docs use workflow.* keys"
	@echo ""
	@echo "Checking operational docs use pvg nd..."
	@for cmd in AGENTS.md .opencode/commands/piv-cancel-loop.md .opencode/commands/piv-init.md .opencode/commands/piv-loop.md .opencode/commands/piv-recover.md .opencode/commands/piv-retro.md .opencode/commands/piv-start.md; do \
		grep -q 'pvg nd' "$$cmd" || (echo "FAIL: $$cmd does not reference pvg nd" && exit 1); \
	done
	@echo "OK: Operational docs reference pvg nd"
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
