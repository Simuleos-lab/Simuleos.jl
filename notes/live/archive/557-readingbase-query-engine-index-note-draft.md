# Draft Index Note: Kernel Interfaces Architecture (Reading + Writing + Engines + Optional Indexes)

## Status
- Draft for review in `notes/live`.
- Intended destination: `notes/index/` (human-managed move).

## Problem
- Simuleos needs a user-facing reading system that remains flexible across terminals and workflows.
- Scope reading is the current focus, but the architecture must support future persisted data kinds.
- We need multiple APIs without duplicating semantics or creating drift.

## Core Decision
- Introduce `Kernel Reading Interface` as the canonical read protocol (SSOT).
- Define it as an abstract system: the collection of all reading mechanisms implemented in the kernel.
- Build multiple user-facing query engines on top of the `Kernel Reading Interface`.
- Query engines can interact with kernel database data only through the `Kernel Reading Interface`.
- Allow optional engine-specific indexes as derived representations (never source of truth).
- Mirror this organization for writes:
  - `Kernel Writing Interface` is the canonical write protocol and abstract system for recording.
  - Recording engines can interact with Simuleos files only through the `Kernel Writing Interface`.

## Layer Model
- Layer 1: Simuleos persisted data (canonical stored state).
- Layer 2a: `Kernel Reading Interface` (canonical read semantics and traversal).
- Layer 2b: `Kernel Writing Interface` (canonical recording semantics).
- Layer 3a: Query engines (user workflow adapters for reading).
- Layer 3b: Recording engines (workflow adapters for writing).
- Layer 4: Terminal-facing APIs (REPL/script/notebook/report/service ergonomics).

## Responsibilities
- `Kernel Reading Interface`:
  - Resolve entities and identities.
  - Traverse canonical records.
  - Materialize values with consistent semantics.
  - Own error semantics for unresolved/invalid reads.
  - Stay generic (not scope-only).
- Query engines:
  - Translate user-friendly operations into `Kernel Reading Interface` calls.
  - Provide ergonomics for each usage style.
  - May add optional index/cache structures.
- `Kernel Writing Interface`:
  - Resolve write targets and recording context.
  - Define canonical append/commit/metadata semantics.
  - Own write-side validation and error semantics.
  - Stay generic across recording data kinds.
- Recording engines:
  - Translate workflow-oriented recording operations into `Kernel Writing Interface` calls.
  - Must not bypass kernel write semantics.
- Indexes (optional):
  - Engine-owned, derived, rebuildable representations.
  - Optimized for latency, filtering, aggregation, or table projection.
  - Must be invalidation/version aware.

## Invariants
- Source-of-truth invariant:
  - Only persisted data + kernel interfaces define canonical meaning.
- No-bypass invariant:
  - Query engines must not read storage directly for canonical semantics.
  - Recording engines must not write storage directly for canonical semantics.
- Equivalence invariant:
  - Different terminal APIs must produce equivalent answers for the same read request.
- Rebuildability invariant:
  - Indexes can be rebuilt from canonical data without loss of truth.

## Design Rationale
- Multiple terminals need different UX forms, but one semantic core.
- `Kernel Reading Interface` prevents semantic duplication and SSOT drift in read workflows.
- `Kernel Writing Interface` does the same for recording workflows.
- Query engines provide velocity for exploration without contaminating core semantics.
- Optional indexes keep performance concerns local to engines.

## Near-Term Direction
- Keep exploration interface simple and unique while discovering useful protocols.
- Start with scope flows through the `Kernel Reading Interface`.
- Expand to additional data kinds without changing the layered contract.

## Open Questions
- Canonical operation set for `Kernel Reading Interface` v0 (minimum complete contract).
- Canonical operation set for `Kernel Writing Interface` v0 (minimum complete contract).
- Standard identity selectors (UUID, label, path-like selector) and ambiguity policy.
- Index lifecycle policy (build trigger, invalidation trigger, versioning keys).
- Cross-engine equivalence test matrix (required scenarios).

## Suggested Next Implementation Notes
- Write `Kernel Reading Interface` protocol note first (operations, invariants, error model).
- Write `Kernel Writing Interface` protocol note second (operations, invariants, error model).
- Map each user-facing API shape to kernel protocols as adapter-only behavior.
- Add anti-drift tests asserting cross-API equivalence over shared fixtures.
