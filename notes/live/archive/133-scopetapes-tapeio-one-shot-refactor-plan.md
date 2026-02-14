# ScopeTapes/TapeIO One-Shot Refactor Plan

## Goal

Refactor Kernel tape systems so:

- `TapeIO` is the only low-level JSONL boundary (path-based, Dict-only).
- `ScopeTapes` is non-session-aware glue over `Scoperias`, `TapeIO`, and `BlobStore`.
- `Stage` is renamed to `ScopeStage`.
- Session-aware code is removed in this pass (to be rebuilt later in `WorkSession`).

## Phase 1 — Introduce TapeIO core and remove session coupling

1. Add path-based `TapeIO` object in Kernel:
   - `TapeIO.path::String`
2. Add low-level TapeIO APIs:
   - `append!(tio::TapeIO, rec::AbstractDict)`:
     - normalize keys to `String`
     - `mkpath(dirname(tio.path))`
     - append one JSON object per line
   - `Base.iterate(::TapeIO)`:
     - lazy JSONL read
     - parse each line to `Dict{String, Any}`
     - throw on invalid JSON line
3. Remove session-based tape navigation APIs and types:
   - `RootHandler`, `SessionHandler`, old `TapeHandler`
   - `sessions`, `tape(session)`, `exists(::TapeHandler)`
   - `_sessions_dir`, `_session_dir`, `_tape_path`

## Phase 2 — Move and reshape ScopeTapes domain objects

1. Move typed record objects to ScopeTapes ownership:
   - `CommitRecord`, `ScopeRecord`, `VariableRecord`
2. Change `CommitRecord` schema:
   - remove `session_label`
   - keep `commit_label`, `metadata`, `scopes`, `blob_refs`
3. Rename `Stage` to `ScopeStage` and update all dependent fields/signatures:
   - `WorkSession.stage::ScopeStage`
   - constructors/usages in app and tests

## Phase 3 — Rewrite ScopeTapes read/write APIs on top of TapeIO

1. Read path:
   - keep typed-only public API: `iterate_tape(tio::TapeIO)`
   - convert Dict entries from TapeIO into typed records in ScopeTapes
   - remove public `iterate_raw_tape` from ScopeTapes
2. Write path:
   - replace `write_commit_to_tape(...)` with one high-level API:
     - `commit_stage!(tio::TapeIO, blob_root::String, stage::ScopeStage, meta::Dict{String, Any}; commit_label::String="")`
   - no `session_label` argument
   - all extra context must live in `meta`

## Phase 4 — Remove session-aware integration code and rewire WorkSession

1. Remove session-aware glue currently embedded in ScopeTapes and path helpers.
2. Rewire `WorkSession` to provide explicit tape path + blob root when committing:
   - resolve path in WorkSession layer (temporary policy for this pass)
   - instantiate `TapeIO` and call `Kernel.commit_stage!(...)`
3. Keep WorkSession compile-valid while stripping old session-navigation assumptions.

## Phase 5 — Tests and cleanup (no backward compatibility)

1. Replace tests that depend on `RootHandler/SessionHandler/TapeHandler`.
2. Add TapeIO-focused tests:
   - append/read roundtrip
   - invalid JSON failure
   - key normalization to string
3. Update ScopeTapes typed read/write tests to use `TapeIO`.
4. Rename all `Stage` references in tests to `ScopeStage`.
5. Remove deprecated aliases and compatibility layers.

## File Targets (expected)

- `src/Kernel/core/types.jl`
- `src/Kernel/core/project.jl`
- `src/Kernel/tapeio/json-I0x.jl` (or split into new TapeIO files)
- `src/Kernel/scopetapes/read-I0x.jl`
- `src/Kernel/scopetapes/read-I1x.jl`
- `src/Kernel/scopetapes/write-I0x.jl`
- `src/Kernel/scopetapes/write-I1x.jl`
- `src/Kernel/scopetapes/handlers-I1x.jl` (delete)
- `src/Kernel/Kernel.jl`
- `src/WorkSession/session-I3x.jl`
- `src/WorkSession/macros-I3x.jl`
- `test/query_tests.jl`
- `test/simignore_tests.jl`
- other tests referencing removed session-aware types/functions

## Acceptance Criteria

1. No session-aware types/APIs remain in Kernel tape subsystems.
2. `TapeIO` can append/read JSONL Dict records independently of `SimOs`.
3. `ScopeTapes.iterate_tape` works from `TapeIO` and yields typed records.
4. Commit path is `ScopeStage -> commit_stage! -> TapeIO.append!`.
5. Test suite passes under `julia --project`.
