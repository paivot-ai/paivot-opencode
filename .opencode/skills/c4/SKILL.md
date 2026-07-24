---
name: c4
description: Architecture-as-code on the machinery design substrate. Use when the user has explicitly enabled the project's design.machinery setting (default off; artifact presence alone does not enable it), when the legacy architecture.c4 setting is enabled, or when the user asks about C4 diagrams, Structurizr, architecture boundaries, dependency rules, the Architecture Contract, the event-contract table, boundary baselining, import drift, or the transition architecture of a rebuild. Maps the Paivot roles onto machinery Phase 2 and its gates (G2, G4, G5 and the ratchet).
version: 2.1.0
---

# Architecture with machinery (C4 + contract)

The canonical architecture is machinery Phase 2: `design/workspace.dsl` (the C4 model in
Structurizr DSL), the machine-checkable Architecture Contract inside
`design/ARCHITECTURE.md`, and, for multi-component designs, the event-contract table
(producer, consumer, payload by Modelith attribute reference, delivery guarantee). The
narrative explains why; the DSL, contract, and table define what, and `machinery check`
holds the line deterministically. This skill is the ROLE ADAPTER: who does what in
Paivot. The formats are documented once, in the machinery skill
(`machinery install --home ~/.agents` places it at `~/.agents/skills/machinery`; point
OpenCode at it or copy it beside these skills; see its `references/c4-standalone.md`
for the Architecture Contract v2, event-contract table, adoption closure, and NFR
record). Never restate the formats here or in stories.

## When this applies

`pvg settings design.machinery`: `off` (default) disables it; `on` promises it (a
missing design fails loudly); `auto` is a deliberate user choice to re-enable artifact
detection (a `.machinery.json` at the root, or `design/domain.modelith.yaml`). The
substrate applies ONLY when the user has explicitly enabled it; the presence of
machinery artifacts does NOT enable it. Enabling machinery is a user decision with
significant token and time cost: agents may RECOMMEND enabling it, stating those
costs, but must never run `pvg settings design.machinery=...` themselves (in
unattended loops, record the recommendation in a story note or comment). Legacy
`architecture.c4=true` projects keep the old narrative-twin flow until the model moves
under `design/`. The `machinery` binary converges via `pvg update`; `pvg doctor` reports
`machinery-reachable`.

## Role map

| Role | Responsibility |
|---|---|
| Architect | Authors Phase 2: `design/workspace.dsl`, `design/ARCHITECTURE.md` with the Architecture Contract (boundaries with `code:` globs, `exposes`, externals, `ignore`, `dependency_rules`), per-dependency failure postures, the NFR record, and, on multi-component designs, the event-contract table with named enumeration sources (machine-checkable format when the design decomposes: pack generation and G5 resolve cells by exact component name and fail loudly on any they cannot). Every technology choice gets its adoption closure enumerated, with closure members carried into the mitigation table. Exit gate: `machinery check design --gate g2` green BEFORE handing to the Sr PM. |
| Architect (brownfield) | Runs `machinery baseline design --impl .`, reviews the proposed `baseline:` rules with the user (a baseline edge is tolerated debt, distinct from an intended `allow:`; add a `deny:` for edges that should die), pastes the survivors, commits `design/ratchet.json`. Any NEW offender file on an amnestied edge then blocks. |
| Architect (rebuild/hybrid) | Adds the `Transition architecture` section to ARCHITECTURE.md: temporary exporter, replication or dual-write, routing, observability, failure posture. Temporary migration dependencies get the full treatment: detection, mitigation, residual, owner. Gm-transition reports narrative-bridge findings until ARCHITECTURE.md and BUILD.md exist; that is expected, not a defect. The migration contract and surface ledger themselves are in the domain-model skill's role map. |
| Sr PM | References contract boundaries and event-contract rows in stories by id; never restates the contract or a payload. |
| Developer | Runs `pvg gates` before delivery: the design gate (machinery check, including G4 import boundaries and the ratchet) runs beside the metric gates and blocks on failure. Never edits generated artifacts (`*.oracle.md`, `formal/*.tla|*.cfg|*.als`, `formal/*.oracle.md`, `packs/`, `pack/`, `ratchet.json`). |
| Anchor | Deterministic pre-pass first (`pvg gates`, `pvg rtm`); attests only what tools cannot: are these the RIGHT boundaries, does every Modelith action have an owning component, are the event-contract table's enumeration sources real (a table with no named source is a claim with no evidence), is the dependency declaration itself complete, is the NFR record real. |

## The deterministic split

The full v0.3.4 suite is `machinery check <design> [--impl <dir>]
[--gate gm,gs,gp,gi,gn,g2,g3,gx,gb,g4,gt,g5]`; gates activate on the artifacts that
exist, fail on absence rather than silently passing, and print `checked:` counts. The
Phase 2 slice: `--gate g2` (G2-c4) verifies the contract parses, binds to
`workspace.dsl`, no duplicate ids, no edge both allowed and denied (or allowed and
baselined), mitigation coverage for every declared external and every
Database/Queue/External-tagged element, and event-contract presence by the header rule.
G4-import (via `pvg gates` on projects with `impl` configured in `.machinery.json`)
verifies the code's import graph against the contract and holds baselined edges to the
ratchet snapshot. G5-pack (automatic on decomposed designs) regenerates packs in
memory, so a lossy event-contract table fails the gate itself, and prints per-pack
boundary-event counts so an unexpected zero is visible. `pvg gates` runs the same
machinery design gate as `machinery check` (identical result, different entry point) --
never treat them as two different gates. Everything else about the architecture is
attested by a named reviewer.

## Boundary debt ceremony (brownfield)

`machinery baseline` reruns tighten the ratchet after burn-down; "ratchet can tighten"
notes are the agenda for the monthly debt review. `ratchet.json` diffs are reviewed in
PRs like contract changes. `ignore:` globs stay unratcheted amnesty; shrink them on the
same cadence.

## Machinery implies hard-TDD

On a project where the user enabled `design.machinery`, once `impl` is configured,
Gt-tests holds the suite to every committed oracle stable id;
the design ships its own test spec. The Paivot rule follows: any story citing oracle
stable ids must carry the `hard-tdd` label (`pvg lint --backlog` enforces this
deterministically as the `hard-tdd-oracle` check); the fusion is conditioned on the
user-enabled setting, never on artifact presence. Label-less stories are for the parts
the machines do not cover; there the label stays user-opt-in, with the Sr PM
recommending it where it would pay off.

## Diagrams

`workspace.dsl` loads into Structurizr tooling; export to `docs/diagrams/` when wanted.
Diagrams are derived; the DSL is the source.
