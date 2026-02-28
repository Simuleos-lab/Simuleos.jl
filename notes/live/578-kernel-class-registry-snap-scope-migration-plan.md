# Kernel Class Registry + `snap.scope` First Migration Plan

Date: 2026-02-27

## Goal

Implement a minimal semantic-class registry in Kernel and migrate `snap.scope` first so capture/write/read all share one class-id contract.

## Scope (this plan)

- In scope: class registry core, `snap.scope` writer/read wiring, tests, and docs updates.
- Out of scope: full migration of `snap.context`, `snap.shared`, and all `src.*` classes.

This note now includes the follow-up migration plan for those out-of-scope classes.

## Phase 1: Minimal registry core

- Add `src/Kernel/classsystem/registry.jl`.
- Define a minimal spec object with fields:
  - `id::String`
  - `version::Int`
  - `compose_from::Vector{String}`
  - optional field schema metadata (names + semantic types/required flags)
- Add registry API:
  - `class_register!(spec)`
  - `class_spec(id)`
  - `class_exists(id)`
  - `class_parse("snap.scope@v1")`
  - `class_tag("snap.scope@v1")` (maps to Julia parametric class tag)
- Add invariant checks:
  - unique ids
  - ids follow `src.*|snap.*|rec.*`
  - `compose_from` refs must exist when declared.
  - class versions are positive integers.

Phase 1 implementation rule:

- Registry is metadata-only and language-agnostic (no function/hook storage).
- Encode/decode/validate behavior lives in Julia multiple-dispatch methods over class tags.

## Phase 2: Bootstrap initial class ids

- Register baseline ids (minimal stubs allowed):
  - `src.codebase`
  - `src.runtime_host`
  - `src.execution_site`
  - `src.namespace_bindings`
  - `src.settings_access`
  - `src.session_state`
  - `snap.scope`
  - `snap.context`
  - `snap.shared`
  - `rec.capture_commit`
  - `rec.ref`
- For this pass, only `snap.scope` gets real encode/decode wiring; others can be no-op/raw passthrough placeholders.
  - In Julia, this means only `snap.scope` gets concrete methods for the class tag in this pass.

## Phase 3: Migrate `snap.scope` write path

- Ensure scope capture output is stamped with class identity and version metadata.
- Ensure commit writer persists `snap.scope` entries with stable class markers.
- Keep existing payload shape for compatibility with current readers/tests.
- Enforce write boundary check: unregistered class ids are invalid for persistence.

## Phase 4: Migrate `snap.scope` read path

- Route scope rehydration through registry metadata + Julia class-tag dispatch for `snap.scope`.
- Update semantic scope readers to rely on registry decode, not ad-hoc direct parse calls.
- Keep public read API unchanged (`ScopeReader` facade remains thin).

## Phase 5: SQLite adapter alignment

- Make scope indexing use the same `snap.scope` decode path from registry-backed Kernel APIs.
- Avoid duplicate parsing semantics in SQLite adapter code.

## Phase 6: Tests and acceptance

- Add unit tests for registry invariants and lookup behavior.
- Add unit tests proving registry has no behavior hooks and behavior resolution is dispatch-based.
- Add migration tests proving `snap.scope` capture->tape->read round-trip still passes.
- Run full test suite and confirm no behavior regression.

## Phase 7: `src.*` class write/read normalization

- `src.codebase`:
  - stamp class metadata on source-capture serialization output
  - add class-tag decode method into source snapshot object
- `src.runtime_host`:
  - stamp class metadata on environment-capture serialization output
  - add class-tag decode method into environment snapshot object
- `src.execution_site`:
  - stamp class metadata on execution-capture serialization output
  - add class-tag decode method into execution snapshot object
- `src.namespace_bindings`:
  - formalize namespace-binding snapshot encoding independent of `snap.scope`
  - add class-tag decode into scope-variable container object
- `src.settings_access`:
  - stamp class metadata on settings-access snapshot payload
  - add class-tag decode into settings snapshot object
- `src.session_state`:
  - stamp class metadata on session-state payload fragments used by context
  - add class-tag decode into session-state snapshot object

## Phase 8: `snap.context` migration

- Write path:
  - stamp `snap.context@v1` on context payload envelope before `rec.ref` write.
  - enforce class registration gate before write.
- Read path:
  - replace ad-hoc dict return path with class-tag decode pipeline for `snap.context`.
  - keep public `context_resolve` API shape stable initially; return decoded object or stable dict adapter.
- Tests:
  - round-trip context capture/resolve with class metadata assertions.
  - backward read compatibility for legacy context records without class marker (if required by policy).

## Phase 9: `snap.shared` migration

- Define explicit encode/decode for `snap.shared` in shared registry operations.
- Option A: keep runtime-only (no tape writes), but ensure internal class-tag validation.
- Option B: if persistence is introduced, write/read through class-gated record path.
- Keep shared bind/merge user behavior unchanged.

## Phase 10: `rec.*` envelope normalization

- `rec.capture_commit`:
  - add explicit class marker for commit envelope.
  - ensure contained scope payloads are class-marked `snap.scope`.
- `rec.ref`:
  - add explicit class marker for generic reference envelopes.
  - include payload class spec field (`payload_class`) for deterministic decode dispatch.
- Add writer guards: reject unknown envelope class ids.

## Phase 11: SQLite and index migration for non-scope classes

- Add adapter/index coverage for `snap.context` first.
- Optionally add index views for selected `src.*` class payloads used in queries.
- Enforce all adapters call class-tag decode path from Kernel (no duplicate parsers).

## Phase 12: global acceptance for all classes

- For every registered class id, define:
  - writer entrypoint
  - reader/decoder entrypoint
  - tests for capture/write/read round-trip
- Add completeness test:
  - registry classes that are marked persistent must have writer+reader methods.
- Confirm there is no remaining ad-hoc semantic parser outside class-tag dispatch paths.

## Definition of done

- Kernel has one class registry SSOT.
- `snap.scope` encode/decode semantics are class-tag dispatch driven, with registry as class metadata gate.
- Existing scope-facing user API continues to work unchanged.
- SQLite scope indexing consumes the same Kernel semantic decode path.

Extended definition of done (all classes):

- All active classes in `src.*`, `snap.*`, and `rec.*` are class-marked at persistence boundaries.
- `snap.context` and `snap.shared` have explicit class-tag encode/decode paths.
- Envelope classes (`rec.capture_commit`, `rec.ref`) carry payload class metadata where needed for deterministic decode.
- SQLite adapters for migrated classes consume Kernel class-tag decode paths only.
- Test suite covers round-trip for every migrated class family.

## Status update

- Phase 1 implemented on 2026-02-27:
  - metadata-only registry scaffold added in `src/Kernel/classsystem/registry.jl`
  - Kernel wiring added in `src/Kernel/Kernel.jl`
  - tests added in `test/class_registry_tests.jl`
- Phase 2 implemented on 2026-02-27:
  - built-in class catalog added in `src/Kernel/classsystem/catalog.jl`
  - bootstrap wiring added in `src/Kernel/Kernel.jl`
  - bootstrap presence assertions added in `test/class_registry_tests.jl`
- Phase 3 implemented on 2026-02-27:
  - `snap.scope` class stamping added on scope serialization in `src/Kernel/scopetapes/write.jl`
  - write boundary class gate added via registry requirement in `src/Kernel/scopetapes/write.jl`
  - gate + marker assertions added in `test/class_registry_tests.jl`
- Phase 4 implemented on 2026-02-28:
  - scope decode now resolves `class_id`/`class_version` and routes through Julia class-tag dispatch in `src/Kernel/scopetapes/base.jl`
  - semantic scope readers now consume the class-dispatch decode path via existing commit/scope read APIs in `src/Kernel/scopetapes/read.jl`
  - class-tag read assertions (valid + invalid class markers) added in `test/class_registry_tests.jl`
