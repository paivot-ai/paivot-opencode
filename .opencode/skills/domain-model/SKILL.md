---
name: domain-model
description: Canonical domain model (entities, relationships, invariants) as a machine-checkable twin of ARCHITECTURE.md, authored with modelith. Use when the project has `dnf.domain_model` enabled in settings, or when the user asks about the domain model, entities, invariants, ubiquitous language, or shared vocabulary during Discovery & Framing. Teaches how the Architect owns the model, the Sr PM turns invariants into acceptance criteria, and the Anchor checks coverage.
version: 1.0.0
---

# Domain Model

Maintain a machine-checkable domain model alongside the narrative ARCHITECTURE.md. It is the single canonical source of the product's entities, how they relate, and the invariants that must always hold. The D&F documents reference it rather than each redefining the vocabulary -- the cure for context divergence (the same concept named differently across BUSINESS.md, DESIGN.md, ARCHITECTURE.md, and the stories).

## When This Applies

Check the project setting:
```bash
pvg settings dnf.domain_model
```

- `true` -- the Architect maintains the model; the Sr PM dereferences it into stories; the Anchor checks coverage
- `false` (default) -- skip entirely, use narrative ARCHITECTURE.md only

## The Tool: modelith

The model is a `*.modelith.yaml` file, linted and rendered by the `modelith` CLI (provisioned by `pvg setup`/`pvg update`; `pvg doctor` reports it).
```bash
modelith --version    # if missing: pvg update
modelith schema       # authoritative format reference -- read before authoring
modelith lint domain.modelith.yaml      # must pass; non-zero = fix the model
modelith render domain.modelith.yaml    # regenerate the committed .md twin
```
The YAML is the output of a conversation, not hand-written. If a concept has no crisp definition, resolve that fuzziness rather than paper over it.

## File Layout

```
domain.modelith.yaml       # Canonical model (linted; the machine-checkable twin)
domain.modelith.md         # Generated Markdown + ER diagram (never hand-edited)
ARCHITECTURE.md            # Narrative architecture (always exists; references the model)
```

## Build Order

Skeleton first, in passes across the whole model:

1. **Skeleton** -- name every entity (crisp definition); declare `relationships`, `cardinality` (`1:1`/`1:n`/`n:1`/`n:n`), and `ownership` (`owned` = a part that cannot exist alone; `referenced` = independent). Renders to an ER diagram.
2. **Behavior** -- add `invariants` (each `{id, statement}`) and `scenarios` (tagged with `invariants_touched`).
3. **Refinement** -- `attributes`, `enums`, `actions`, `glossary` roles, only where they add clarity.

Entity keys are PascalCase; backtick entity names in freeform text.

## Agent Responsibilities

- **Architect**: owns `domain.modelith.yaml`; authors it skeleton-first from the BA/Designer concepts; keeps it consistent with ARCHITECTURE.md's data architecture (the model is canonical); runs `modelith lint`/`render` on every change. It is a protected, architect-owned D&F artifact: the guard blocks writes to `*.modelith.yaml` unless the Architect is active.
- **Sr PM**: uses entity/attribute names verbatim from the model; turns each invariant into an EARS Ubiquitous acceptance criterion; adds `domain-model` to the story's MANDATORY SKILLS TO REVIEW section.
- **Developer**: reads the model for the entities/invariants the story touches; uses canonical names; upholds invariants; raises (does not silently diverge) if code forces a concept change.
- **Anchor**: checks coverage -- every entity touched by a story, every invariant mapped to an acceptance criterion, no story renames a modeled concept, the `.md` twin in sync with the `.yaml`.
