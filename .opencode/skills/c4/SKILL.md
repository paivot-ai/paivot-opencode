---
name: c4
description: Architecture-as-code using C4 model and Structurizr DSL. Use when the project has `architecture.c4` enabled in settings, or when the user asks about C4 diagrams, Structurizr, architecture boundaries, or dependency rules. Teaches agents how to maintain a canonical architecture model alongside ARCHITECTURE.md, declare machine-checkable boundaries, and export diagrams.
version: 1.0.0
---

# C4 Architecture Model

Maintain a machine-checkable C4 architecture model alongside the narrative ARCHITECTURE.md.

## When This Applies

Check the project setting:
```bash
pvg settings architecture.c4
```

- `true` -- maintain the model, enforce boundaries, generate diagrams
- `false` (default) -- skip entirely, use narrative ARCHITECTURE.md only

## File Layout

```
workspace.dsl              # Canonical C4 model (Structurizr DSL)
docs/diagrams/             # Generated diagram artifacts
ARCHITECTURE.md            # Narrative architecture (always exists)
```

## Structurizr DSL Quick Reference

```
workspace "Project Name" "Description" {
    model {
        user = person "User" "End user"
        system = softwareSystem "My System" "What it does" {
            web = container "Web App" "UI" "React"
            api = container "API" "Logic" "Go"
            db  = container "Database" "Storage" "PostgreSQL" "Database"
        }
        user -> web "Uses" "HTTPS"
        web -> api "Calls" "REST/JSON"
        api -> db "Reads/writes" "SQL"
    }
    views {
        systemContext system "Context" { include *; autoLayout }
        container system "Containers" { include *; autoLayout }
    }
}
```

## Architecture Contract

Embedded in ARCHITECTURE.md as parseable YAML:

```yaml
contract_version: 1
boundaries:
  - id: billing.service
    kind: container
    code: ["services/billing/**"]
    exposes: ["services/billing/api/**"]
dependency_rules:
  allow: ["billing.service -> shared.domain"]
  deny: ["billing.service -> *.database_direct"]
```

## Agent Responsibilities

- **Architect**: creates/maintains workspace.dsl and Architecture Contract
- **Sr PM**: adds boundary AC to stories, references c4 skill
- **Developer**: reads contract before coding, verifies no boundary violations
- **Anchor**: validates boundaries match code paths in reviews
