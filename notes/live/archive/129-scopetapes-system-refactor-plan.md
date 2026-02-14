# ScopeTapes System - Decisions

**Issue**: The current low-level design is asymmetric (`QueryNav` for read vs Recorder pipeline for write). We need one unified low-level subsystem for scope tape storage/read/write.

**Q**: Should ScopeTapes integrate with Scoperias, or the opposite?
**A**: ScopeTapes integrates with Scoperias (Scoperias remains a lower-level dependency).

**Q**: Should low-level unification use a dedicated SSOT kernel module?
**A**: Yes. Use `Kernel/scopetapes/` as the SSOT for low-level scope tape logic.

**Q**: Should user-facing APIs (`@session_*`, current Reader interface) be renamed now?
**A**: No. Keep user-facing names/workflow stable for now; reimplement internals only.

**Q**: Should session/git policy and other high-level lifecycle behavior be refactored now?
**A**: No. Defer lifecycle concerns (possible future `LiveSession` subsystem). This refactor only targets low-level ScopeTapes unification.

**Decision**: Perform a one-shot low-level refactor that consolidates read/write scope tape internals under `Kernel/scopetapes/`, keeps current app-level workflows intact, and removes obsolete split internals (`scopenav` + recorder pipeline split) without backward-compat code.

## One-Shot Refactor Plan (Low-Level ScopeTapes)

### 1) Define target kernel topology (SSOT)

Create `src/Kernel/scopetapes/` with explicit read/write split:

- `handlers-I1x.jl`
  - session/tape/blob handler navigation and existence checks.
- `read-I0x.jl`
  - raw dict -> typed record constructors (`CommitRecord`, `ScopeRecord`, `VariableRecord`).
- `read-I1x.jl`
  - raw tape iteration, typed tape iteration, blob loading.
- `write-I0x.jl`
  - scope/commit JSON serialization, blob-ref computation, write-time lite/blob classification.
- `write-I1x.jl`
  - scope fill from locals/globals into `CaptureContext`; append commit to tape.

Notes:
- `ScopeTapes` depends on `Scoperias`, `BlobStore`, and `TapeIO` utilities.
- Keep `Kernel/core/types.jl` as type SSOT (no type migration out of Core in this pass).

### 2) Move/rename low-level functions into ScopeTapes

From `Kernel/scopenav/*` -> `Kernel/scopetapes/read*` + `handlers-I1x.jl`:
- `sessions`, `tape`, `blob`, `exists(::TapeHandler)`, `exists(::BlobHandler)`
- `_raw_to_variable_record`, `_raw_to_scope_record`, `_raw_to_commit_record`
- `iterate_raw_tape`, `iterate_tape`, `collect(Vector{CommitRecord}, handler)`, `Base.iterate(::TapeHandler, ...)`
- `load_raw_blob`, `load_blob`

From `Recorder/pipeline-I0x.jl` -> `Kernel/scopetapes/write-I0x.jl`:
- `_get_type_string`
- `_compute_blob_refs`
- `_write_variable_json`
- `_write_capture_json`
- `_write_commit_record`
- `MAX_TAPE_SIZE_BYTES`
- `_should_ignore_var` (or split into a dedicated internal helper file under `scopetapes/`)

From `Recorder/pipeline-I1x.jl` -> `Kernel/scopetapes/write-I1x.jl`:
- `_fill_scope!`
- `write_commit_to_tape`

### 3) Rewire module includes and call sites

Update `src/Kernel/Kernel.jl`:
- include new `scopetapes/*` files.
- remove includes of old `scopenav/*` files.

Update app modules to consume kernel ScopeTapes internals:
- `Recorder/macros-I3x.jl` and related code call `Kernel._fill_scope!` / `Kernel.write_commit_to_tape` from new kernel location.
- `Reader` continues as workflow façade; it uses kernel ScopeTapes read APIs (same names if retained).

Update `Recorder/Recorder.jl`:
- remove includes for old pipeline files once moved.

### 4) Delete obsolete low-level split files (no compatibility layer)

Delete after rewiring:
- `src/Kernel/scopenav/handlers-I1x.jl`
- `src/Kernel/scopenav/loaders-I0x.jl`
- `src/Kernel/scopenav/loaders-I1x.jl`
- `src/Recorder/pipeline-I0x.jl`
- `src/Recorder/pipeline-I1x.jl`

Do not keep alias wrappers or deprecated forwarding functions.

### 5) Keep high-level workflow state unchanged in this pass

No changes in this refactor to:
- session lifecycle semantics (`@session_init`, dirty-git guard)
- `SimOs.recorder` / `SimOs.reader` state holders
- naming of current user-facing API

### 6) Tests and acceptance gates

Run full suite:
- `julia --project test/runtests.jl`

Add/adjust tests to prove low-level unification behavior parity:
- read path still iterates and loads typed records from tape
- write path still serializes commits and blob refs correctly
- `Recorder`/`Reader` user-level behavior unchanged

Acceptance criteria:
- No references remain to deleted low-level files.
- All old read/write low-level responsibilities now live in `Kernel/scopetapes/`.
- Tests pass without compatibility shims.

### 7) Documentation sync (same refactor)

Update:
- `notes/index/subsystem-arch.md`
  - replace `QueryNav` entry with `ScopeTapes` kernel subsystem responsibilities (read + write).
- `notes/index/workflows.md` and any affected architecture index note pointing to old split.

