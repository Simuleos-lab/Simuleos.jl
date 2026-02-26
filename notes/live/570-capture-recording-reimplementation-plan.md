# 570 — Capture & Recording System Reimplementation Plan

**Date:** 2026-02-25
**Status:** Implemented (Phases 1-5, 7 done; Phase 6 reverted by design)
**Predecessors:** 566, 567, 568, 569
**Scope:** phased incremental reimplementation of capture and recording subsystems

---

## Context

Simuleos needs a general-purpose capture and recording architecture (design notes 566-569). Today, `scope.capture` conflates state collection with blob I/O, `WorkSession` mixes capture config with recording state, and there's no way to capture settings provenance or get lightweight provenance stamps. This plan introduces the two independent subsystems (Capture → Snapshot, Recording → Record) incrementally, keeping all existing tests and `@simos` commands working at every step.

---

## Phase 1 — Capture types and pure collectors

**Goal:** Introduce `PartialCapture` subtypes and pure collection functions. Zero changes to existing code.

**New files:**
- `src/Kernel/core/capture_types.jl` — types: `PartialCapture` (abstract), `SettingsCapture`, `SourceCapture`, `EnvironmentCapture`, `ExecutionCapture`, `ScopeCapture`, `MetaCapture`
- `src/Kernel/capture/collectors.jl` — pure functions: `capture_source(gh)`, `capture_environment()`, `capture_execution()`
- `src/Kernel/capture/serialization.jl` — bridge: `serialize_capture(c) → Dict`, `deserialize_capture(d) → PartialCapture`
- `test/capture_types_tests.jl` — constructor tests, round-trip serialization, graceful `capture_source(nothing)`

**Modify:**
- `src/Kernel/Kernel.jl` — add includes after `gitmeta/git.jl`
- `test/runtests.jl` — add `include("capture_types_tests.jl")` after `scoperias_tests.jl`

---

## Phase 2 — Settings access tracking

**Goal:** Instrument `get_setting` to log accessed keys between captures.

**Modify:**
- `src/Kernel/core/types.jl` — add to `WorkSession`: `settings_access_log::Union{Nothing, Dict{String,Any}}`, `settings_access_tracking::Bool`
- `src/Kernel/core/base.jl` — default new fields (`nothing`, `true`)
- `src/Kernel/core/settings.jl` — in `get_setting`: if ws active + tracking on + log not nothing → `log[key] = value`
- `src/WorkSession/session.jl` — in `session_init!`: set `ws.settings_access_log = Dict{String,Any}()`
- `src/WorkSession/macros.jl` — add `_flush_settings_access_log!(ws)` → returns `Dict{String,Any}`, replaces log with fresh dict
- `src/SimosAPI/macro.jl` — add `settings.tracking.on` / `settings.tracking.off` commands

**New files:**
- `test/settings_tracking_tests.jl` — log population, flush, tracking toggle

---

## Phase 3 — Source/environment/execution collectors in session lifecycle

**Goal:** Capture source + environment once at session init; execution per scope.

**Modify:**
- `src/Kernel/core/types.jl` — add to `WorkSession`: `source_capture::Union{Nothing, SourceCapture}`, `environment_capture::Union{Nothing, EnvironmentCapture}`
- `src/WorkSession/session.jl` — in `session_init!`: `ws.source_capture = capture_source(gh)`, `ws.environment_capture = capture_environment()`
- `src/WorkSession/macros.jl` — in `scope_capture`: attach `capture_execution()` fields to scope metadata

**Tests:** extend `test/capture_types_tests.jl`

---

## Phase 4 — Recording primitives (`RecordRef`, `record_write`, `record_resolve`)

**Goal:** Content-addressed generalized tape writing. Independent of phases 2-3.

**New files:**
- `src/Kernel/tapeio/record.jl` — `RecordRef` type, `record_content_hash(data)`, `record_write(tape, data) → RecordRef`, `record_resolve(tape, ref) → Dict|nothing`
- `test/recording_tests.jl` — determinism, round-trip, prefix lookup, string interpolation

**Modify:**
- `src/Kernel/core/types.jl` — add `RecordRef` struct (hash, short; `Base.string` → short)
- `src/Kernel/tapeio/json.jl` — add `_write_json_sorted` for stable hashing
- `src/Kernel/Kernel.jl` — add `include("tapeio/record.jl")` after `tape.jl`
- `test/runtests.jl` — add `include("recording_tests.jl")`

**Compatibility:** new `generic_record` tape type is ignored by existing `CommitIterator` (filters on `type == "commit"`).

---

## Phase 5 — `@simos context.capture` and `context.resolve`

**Goal:** User-facing provenance stamp commands. Composes phases 2-4.

**New files:**
- `src/WorkSession/context.jl` — `context_capture!(ws, proj) → RecordRef` (flushes settings log, assembles tree with source/env/execution, calls `record_write`), `context_resolve(proj, ws, ref_str) → Dict|nothing`
- `test/context_capture_tests.jl`

**Modify:**
- `src/WorkSession/WorkSession.jl` — add `include("context.jl")`
- `src/SimosAPI/macro.jl` — add `context.capture` and `context.resolve` commands
- `test/runtests.jl` — add test include

**User surface:**
```julia
ref = @simos context.capture()       # → RecordRef
savefig("plot_$(ref).png")           # short hash in filename
data = @simos context.resolve(ref)   # → full context Dict
```

---

## Phase 6 — Defer blob writes from capture to recording time

**Status: REVERTED** — Implemented then reverted. Deferring blob writes is unsafe:
1. Objects can mutate between capture and commit, recording wrong state.
2. Large objects held in memory too long before commit flushes them.
3. Semantically, capture means "snapshot now" — blobs must be written at capture time.

Blob writes remain at capture time in `_make_scope_variable`.

**Original goal (not pursued):** Make `scope.capture` pure (no disk I/O). Blobs written at `session.commit`.

**Original plan:**
- `src/Kernel/core/types.jl` — add `BlobPending <: ScopeVariable` (level, type_short, key, value)
- `src/Kernel/scoperias/base.jl` — in `_make_scope_variable`: blob branch returns `BlobPending` instead of calling `blob_write`
- `src/Kernel/scopetapes/write.jl` — add `commit_to_tape!(tape, commit, storage)` overload that flushes `BlobPending → BlobScopeVariable` before writing; add `_write_json(io, BlobPending)` that errors as safety net
- `src/WorkSession/macros.jl` — pass `proj.blobstorage` to `commit_to_tape!` in `session_commit`, `_flush_pending_commits!`
- `test/scoperias_tests.jl` — update blob assertions (check after commit, not after capture)

---

## Phase 7 — CLI args layer (independent, can parallelize with 2-6)

**Goal:** `@simos settings.source.add_args(ARGS)` for `--set key=value` and `--config path.json`.

**New files:**
- `src/Kernel/core/cli_args.jl` — `parse_cli_args(args) → Dict{String,Any}`, `_coerce_cli_value(s)`
- `test/cli_args_tests.jl`

**Modify:**
- `src/Kernel/core/cli_args.jl` — add `settings_source_add_args!(simos, args; after=:env)` (placed here instead of settings.jl for better separation)
- `src/Kernel/Kernel.jl` — add include
- `src/SimosAPI/macro.jl` — add `settings.source.add_args` command
- `test/runtests.jl` — add test include

**Layer priority:** `:home < :project < :json_file < :env < :cli < :bootstrap < :script < :session`

---

## Dependency graph

```
Phase 1 (types + collectors)
  ├→ Phase 2 (settings tracking)
  │    └→ Phase 3 (collectors in lifecycle)
  │         └→ Phase 5 (context.capture)
  ├→ Phase 4 (recording primitives)
  │    └→ Phase 5 (context.capture)
  ├→ Phase 6 (defer blob writes) — REVERTED
  └→ Phase 7 (CLI args) — independent, parallel with 2-6
```

---

## Verification

After each phase:
1. Run `julia --project test/runtests.jl` — all existing tests pass
2. Run the new phase-specific test file
3. Run `examples/workflows/001-record-read-roundtrip.jl` — end-to-end smoke test

After Phase 5: verify `@simos context.capture()` returns a `RecordRef` and `@simos context.resolve(ref)` returns the full tree.

After Phase 7: verify `julia --project script.jl --set run.alpha=0.5` overrides settings.
