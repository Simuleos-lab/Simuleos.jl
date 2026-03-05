# 583 — DataClass Runtime Reimplementation Plan

Date: 2026-03-04
Status: Executed (2026-03-04)
Scope: Replace runtime `SimuleosClass{ID,V}` dict-wrapper objects with explicit Julia structs per semantic class, while keeping the class registry as semantic SSOT.

## Intent

- Keep the registry as the language-agnostic existence/identity contract for semantic classes across runtime and disk.
- Use explicit runtime structs for every active class version.
- Make capture outputs and persisted decode results typed DataClasses.
- Remove dict-wrapper runtime handling and key-by-key field access patterns.

## Architecture Decisions

1. Registry remains semantic SSOT
- `ClassSystem/registry.jl` and `ClassSystem/catalog.jl` remain the source of truth for class id/version existence and metadata.
- Registry continues to represent class contracts broader than Julia runtime objects (for example disk records and cross-language semantics).

2. Runtime representation switches to DataClass structs
- Introduce one abstract runtime base: `SimuleosDataClass`.
- Every class runtime object is a concrete struct subtype of `SimuleosDataClass`.
- Class tags stay as dispatch selectors for decode routing only; tags are no longer dict payload wrappers.

3. Lifecycle boundary
- Standardize all class flows as:
  - `RuntimeRaw::Dict -> RuntimeStruct <: SimuleosDataClass -> DiskRaw::Dict`
- Remove persisted decode APIs that return plain dicts for class payloads.

4. Backward compatibility policy
- Do not keep legacy wrapper aliases or compatibility branches.
- Remove old wrapper-based tests once migrated.

## Implementation Phases

## Phase 1 — Core Type Model Replacement

1. Replace wrapper-based runtime core
- Remove runtime dependence on `SimuleosClass{ID,V}` in `Foundation/dataclass_types.jl`.
- Add abstract runtime base `SimuleosDataClass`.
- Keep `PartialSnapshot` only if still needed during transition; final target is a single base runtime capture type.

2. Update shared type containers
- Migrate `CaptureTree.snapshots` element type from `PartialSnapshot` to `SimuleosDataClass`.
- Update helper signatures that assume wrapper aliases.

3. Preserve registry API surface
- Keep class parse/spec/register/query API stable.
- Ensure class-tag dispatch helpers stay available for decode selection.

## Phase 2 — Reimplement Every Active Class as a Concrete Runtime Struct

Each listed registry class must receive a dedicated runtime struct and explicit encode/decode pair.

1. `src.codebase@v1`
- Implement `SrcCodebaseV1 <: SimuleosDataClass`.
- Replace wrapper alias behavior in `Classes/src/codebase.jl`.

2. `src.runtime_host@v1`
- Implement `SrcRuntimeHostV1 <: SimuleosDataClass`.
- Replace wrapper alias behavior in `Classes/src/runtime_host.jl`.

3. `src.execution_site@v1`
- Implement `SrcExecutionSiteV1 <: SimuleosDataClass`.
- Replace wrapper alias behavior in `Classes/src/execution_site.jl`.

4. `src.namespace_bindings@v1`
- Implement `SrcNamespaceBindingsV1 <: SimuleosDataClass`.
- Stop reusing `snap.scope` runtime type for `src.namespace_bindings` payloads.

5. `src.settings_access@v1`
- Implement `SrcSettingsAccessV1 <: SimuleosDataClass`.
- Replace wrapper alias behavior in `Classes/src/settings_access.jl`.

6. `src.session_state@v1`
- Implement `SrcSessionStateV1 <: SimuleosDataClass`.
- Replace dict-return decode in `Classes/src/session_state.jl` with typed decode.

7. `snap.scope@v1`
- Implement `SnapScopeV1 <: SimuleosDataClass`.
- Replace `ScopeSnapshot = SimuleosClass{...}` alias model.

8. `snap.context@v1`
- Implement `SnapContextV1 <: SimuleosDataClass`.
- Replace dict-return decode in `Classes/snap/context.jl` with typed decode.

9. `snap.shared@v1`
- Implement `SnapSharedV1 <: SimuleosDataClass`.
- Replace `SharedScopeSnapshot = SimuleosClass{...}` alias model.

10. `rec.capture_commit@v1`
- Implement `RecCaptureCommitV1 <: SimuleosDataClass`.
- Decode persisted commit envelopes into `RecCaptureCommitV1` rather than workflow container objects.

11. `rec.ref@v1`
- Implement `RecRefV1 <: SimuleosDataClass`.
- Replace dict-return decode in `Classes/rec/ref.jl` with typed envelope decode.

## Phase 3 — Workflow Container Separation

1. Clarify `CaptureTree` role
- Treat `CaptureTree` as internal mutable workflow staging/assembly container only.
- Do not model `CaptureTree` as a semantic DataClass.

2. Add explicit conversion boundaries
- Stage container to semantic record conversion:
  - `CaptureTree` (or renamed `CaptureStage`) -> `RecCaptureCommitV1` -> disk raw record.

3. Remove implicit mixed semantics
- Ensure persisted commit semantics are represented by `RecCaptureCommitV1` only.

## Phase 4 — Cross-Subsystem Wiring Updates

1. Serialization dispatch
- Update `Workflows/capture/serialization.jl` to dispatch on concrete `SimuleosDataClass` implementations.

2. Sessiontrace read/write paths
- Update `Workflows/sessiontrace/scopetapes/base.jl`, `read.jl`, and `write.jl` to consume new typed classes.

3. WorkSession integration
- Update `WorkSession/session.jl` for typed session-state decode/encode.
- Update `WorkSession/context.jl` for typed `snap.context` decode/encode.
- Update `WorkSession/shared.jl` for typed `snap.shared` handling.

4. SQLite indexing alignment
- Update `SQLiteIndex/session_index.jl` and related adapters to consume typed class decode outputs where class payloads are read.

## Phase 5 — Validation and Contract Enforcement

1. Runtime constructor validation
- Move required field and invariant checks into struct constructors or dedicated validators.

2. Registry to runtime completeness
- Add tests ensuring every registered persistent class has:
  - one runtime struct subtype,
  - one encode path,
  - one decode path,
  - one class-tag dispatch route.

3. Eliminate dict-return class decoders
- Add tests asserting persisted class decode APIs do not return raw dicts.

## Phase 6 — Test Migration and Acceptance

1. Replace wrapper-centric tests
- Update `test/dataclass_types_tests.jl` and any tests tied to `SimuleosClass{ID,V}` wrapper aliases.

2. Expand class-registry integration tests
- Extend `test/class_registry_tests.jl` to enforce runtime DataClass coverage and decode completeness.

3. Update end-to-end behavior tests
- Migrate affected assertions in:
  - `test/recording_tests.jl`
  - `test/scope_reader_tests.jl`
  - `test/context_capture_tests.jl`
  - `test/worksession_tests.jl`
  - `test/sqlite_index_tests.jl`

4. Full suite pass
- Run `julia --project` full tests after migration.

## DataClasses To Reimplement (Canonical Checklist)

- `SrcCodebaseV1` for `src.codebase@v1`
- `SrcRuntimeHostV1` for `src.runtime_host@v1`
- `SrcExecutionSiteV1` for `src.execution_site@v1`
- `SrcNamespaceBindingsV1` for `src.namespace_bindings@v1`
- `SrcSettingsAccessV1` for `src.settings_access@v1`
- `SrcSessionStateV1` for `src.session_state@v1`
- `SnapScopeV1` for `snap.scope@v1`
- `SnapContextV1` for `snap.context@v1`
- `SnapSharedV1` for `snap.shared@v1`
- `RecCaptureCommitV1` for `rec.capture_commit@v1`
- `RecRefV1` for `rec.ref@v1`

## Completion Criteria

1. All active registry classes have explicit runtime DataClass structs.
2. No active runtime flow depends on `SimuleosClass{ID,V}` dict-wrapper payload objects.
3. Persisted decode interfaces return typed DataClasses.
4. Registry remains semantic SSOT and runtime structs remain Julia-specific representation.
5. Full test suite passes under `julia --project`.
