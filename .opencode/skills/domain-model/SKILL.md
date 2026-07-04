---
name: domain-model
description: Canonical domain model and its derivation chain on the machinery design substrate. Use when the project's design.machinery setting applies (auto detects a machinery-managed repo), when the legacy dnf.domain_model setting is enabled, or when the user asks about the domain model, entities, invariants, ubiquitous language, state machines, oracles, stable ids, or how stories derive from the design.
---

# Domain model in D&F (machinery Phases 1 and 3)

The model is `design/domain.modelith.yaml`, authored with modelith and linted by
`modelith lint`: the single canonical source of the product's entities, relationships,
and invariants. The three D&F documents reference it; they never redefine vocabulary.
On the machinery substrate it starts a derivation chain: lifecycle enums become state
machines (Phase 3), machines generate transition oracles, and oracle rows carry
content-derived STABLE IDS (tokens like `DEAL-eb0c40`) that stories and tests key on.

## When this applies

`pvg settings design.machinery` resolves it (auto | on | off), same as the c4 skill.
Legacy `dnf.domain_model=true` keeps the v1 flow until the model moves under `design/`.
Both `modelith` and `machinery` converge via `pvg update`.

## Role map

| Role | Responsibility |
|---|---|
| BA / Designer | Feed the interrogation: what exists, what must always be true, where one word carries two meanings. Brownfield: for every tangle, ask "this looks messy because <specific observation>; what is your desired end state?" The code says what IS; only the user can say what SHOULD BE. |
| Architect | Owns the model (gate: `modelith lint` clean; every lifecycle entity has a status enum; every invariant an owner) and Phase 3: one machine per stateful component, then `machinery oracle design/machines`. A machine edit and its regenerated oracle land in the SAME change; staleness is DRIFT and blocks. |
| Sr PM | Dereferences the model into stories: invariants become ACs; for machine-covered slices the ORACLE ROWS are the test spec and ACs cite stable ids verbatim (whole tokens). `pvg rtm` fails when any oracle id has no covering story; run it before Anchor submission. Model the stateful core only. |
| Anchor | `pvg rtm` in the deterministic pre-pass ([ORACLE] rows use exact token matching). Attest what the tool cannot: whether the invariants are the RIGHT ones; a shallow model gates clean. |
| Developer | Derives hard-TDD RED tests from the cited oracle rows, keyed on stable ids. `pvg story approve-red` verifies coverage deterministically before the suite locks. |
| PM | On design revisions, `pvg story sync-oracle --base <ref>` maps the stable-id diff onto affected stories. |

## Codebase archaeology (brownfield)

Excavate the model from code, schema, and production data AS IT IS; record incoherence
as open questions. When a codebase-graph MCP is available (codebase-memory-mcp or
equivalent), index the repository first and drive the excavation through its tools
instead of grep. Start this dialog on day one, in parallel with the boundary baseline.

## Format and deep dives

`modelith schema` for the YAML format. The four-phase pipeline, machine annotations,
oracle contract, and revision mode: the machinery skill (`machinery install --home ~/.agents`) and its references. Reference formats, never restate them.
