---
name: c4
description: Architecture-as-code on the machinery design substrate. Use when the project's design.machinery setting applies (auto detects a machinery-managed repo), when the legacy architecture.c4 setting is enabled, or when the user asks about C4 diagrams, Structurizr, architecture boundaries, dependency rules, the Architecture Contract, boundary baselining, or import drift. Maps the Paivot roles onto machinery Phase 2.
---

# Architecture with machinery (C4 + contract)

The canonical architecture is machinery Phase 2: `design/workspace.dsl` (the C4 model in
Structurizr DSL) plus the machine-checkable Architecture Contract inside
`design/ARCHITECTURE.md`. The narrative explains why; the DSL and contract define what,
and `machinery check` holds the line deterministically. This skill is the ROLE ADAPTER:
who does what in Paivot. The format itself is documented once, in the machinery skill
(`machinery install --home ~/.agents` places it at `~/.agents/skills/machinery`; point
OpenCode at it or copy it beside these skills; see its `references/c4-standalone.md`). Never restate the format here or in
stories.

## When this applies

`pvg settings design.machinery`: `auto` (default) applies exactly when the repo is
machinery-managed (a `.machinery.json` at the root, or `design/domain.modelith.yaml`);
`on` promises it (a missing design fails loudly); `off` disables it. Legacy
`architecture.c4=true` projects keep the old narrative-twin flow until the model moves
under `design/`. The `machinery` binary converges via `pvg update`; `pvg doctor` reports
`machinery-reachable`.

## Role map

| Role | Responsibility |
|---|---|
| Architect | Authors Phase 2: `design/workspace.dsl`, `design/ARCHITECTURE.md` with the Architecture Contract (boundaries with `code:` globs, `exposes`, externals, `ignore`, `dependency_rules`), per-dependency failure postures, the NFR record. Exit gate: `machinery check design --gate g2` green BEFORE handing to the Sr PM. |
| Architect (brownfield) | Runs `machinery baseline design --impl .`, reviews the proposed `baseline:` rules with the user (a baseline edge is tolerated debt, distinct from an intended `allow:`; add a `deny:` for edges that should die), pastes the survivors, commits `design/ratchet.json`. Any NEW offender file on an amnestied edge then blocks. |
| Sr PM | References contract boundaries in stories by id; never restates the contract. |
| Developer | Runs `pvg gates` before delivery: the design gate (machinery check, including G4 import boundaries and the ratchet) runs beside the metric gates and blocks on failure. Never edits generated artifacts (`*.oracle.md`, `formal/*.tla|*.cfg`, `packs/`, `pack/`, `ratchet.json`). |
| Anchor | Deterministic pre-pass first (`pvg gates`, `pvg rtm`); attests only what tools cannot: are these the RIGHT boundaries, does every Modelith action have an owning component, is the NFR record real. |

## Boundary debt ceremony (brownfield)

`machinery baseline` reruns tighten the ratchet after burn-down; "ratchet can tighten"
notes are the agenda for the monthly debt review. `ratchet.json` diffs are reviewed in
PRs like contract changes. `ignore:` globs stay unratcheted amnesty; shrink them on the
same cadence.

## Diagrams

`workspace.dsl` loads into Structurizr tooling; export to `docs/diagrams/` when wanted.
Diagrams are derived; the DSL is the source.
