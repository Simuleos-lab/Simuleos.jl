# WorkSession System - Decisions

**Issue**: Simuleos needs one higher-level abstraction to own session workflows, while keeping low-level tape I/O in Kernel ScopeTapes and preserving lazy disk access.

**Q**: Where should `WorkSession` live first?
**A**: App-level subsystem (`WorkSession/`, I2x-I3x). Kernel keeps low-level primitives.

**Q**: Active-session model in `SIMOS`?
**A**: Single active `sim.worksession` replaces `sim.recorder` and `sim.reader`.

**Q**: What should `WorkSession` own?
**A**: Full code-session workflow (init, stage/capture orchestration, commit orchestration).

**Q**: What state should `WorkSession` store for tapes?
**A**: Store only what is needed to load on demand (session identity + workflow state). No hidden in-memory disk snapshots/caches.

**Q**: Module cut in this refactor?
**A**: Replace `Recorder` and `Reader` as top-level App subsystems with `WorkSession` (no compatibility layer).

**Q**: High-level read API in this pass?
**A**: Remove high-level read API for now; keep read access at Kernel ScopeTapes level.

**Q**: `@session_commit` lifecycle?
**A**: Commit clears staged data; it does not end the active work session.

**Q**: Macro rename timing?
**A**: Keep current user-facing macro names for now; rename later.

**Decision**: Build a single App subsystem `WorkSession` that owns session workflow state and orchestration, delegates all disk-backed read/write operations to `Kernel.ScopeTapes`, removes `Recorder`/`Reader` high-level split, and keeps user macro names unchanged in this pass.

## One-Shot Refactor Plan (WorkSession Unification)

### 1) Introduce `WorkSession` App subsystem

Create `src/WorkSession/`:
- `WorkSession.jl` (module root, includes I0x/I1x/I3x files)
- `types-I0x.jl` (if needed for app-level helpers only; keep core types in Kernel.Core)
- `session-I3x.jl` (init/get/guards for active session on `SIMOS`)
- `macros-I3x.jl` (`@session_init`, `@session_store`, `@session_context`, `@session_capture`, `@session_commit`)
- `simignore-I0x/I1x/I3x.jl` (or move logic to WorkSession equivalents if still needed)

Notes:
- Keep macro names unchanged.
- Use explicit imports and fully qualified references.

### 2) Replace `SIMOS` state slots

In `src/Kernel/core/types.jl`:
- Remove fields:
  - `recorder`
  - `reader`
- Add field:
  - `worksession::Any = nothing` (later can be narrowed once type stabilization is desired)

Replace old state holders with a unified one:
- Remove `SessionRecorder` and `SessionReader`.
- Add `WorkSessionState` (name can be final at implementation), containing:
  - `label::String`
  - `stage::Stage`
  - `meta::Dict{String, Any}`
  - `simignore_rules::Vector{Dict{Symbol, Any}}`
  - `_settings_cache::Dict{String, Any}`

Keep:
- `CaptureContext`, `Stage`, handler/record types in Kernel.Core (SSOT).

### 3) Move high-level workflow logic into `WorkSession`

Migrate from `src/Recorder/*`:
- Session init and metadata capture flow.
- Simignore settings and rule resolution used by capture.
- Macro/function forms for store/context/capture/commit.

Required behavior:
- `@session_capture` and function form build stage via Kernel helpers and ScopeTapes writer flow.
- `@session_commit` writes through `Kernel.write_commit_to_tape(...)`, then resets `stage` only.
- Active session remains in `SIMOS[].worksession` after commit.

### 4) Remove top-level `Recorder` and `Reader` app subsystems

Delete (no aliases, no forwarding wrappers):
- `src/Recorder/Recorder.jl`
- `src/Recorder/*.jl` (all files once migrated)
- `src/Reader/Reader.jl`
- `src/Reader/*.jl` (all files)

Update `src/Simuleos.jl`:
- Stop including/importing `Recorder` and `Reader`.
- Include/import `WorkSession`.
- Export the same session macros from `WorkSession` for now.

### 5) Keep Kernel ScopeTapes as the only disk I/O boundary

App-level `WorkSession` must only interact with tape/blob data via `Kernel.ScopeTapes` APIs:
- write path: `_fill_scope!`, `write_commit_to_tape`, related helpers
- read path: if needed internally, only through `Kernel` handlers/loaders

Do not:
- Recreate filesystem layout logic in `WorkSession`.
- Cache full tape/commit/blob disk data in `WorkSession` state.

### 6) Remove high-level read API for now

Given the decision to defer user-facing read workflow:
- Remove any app-level read/session-reader helpers.
- Keep only Kernel read primitives and typed iterators (`sessions`, `tape`, `iterate_tape`, blob loaders, etc.).
- Update tests to stop depending on `Reader` app state.

### 7) Tests and acceptance gates

Update tests:
- Replace recorder-state assertions with `worksession` assertions.
- Ensure commit no longer clears the active session object, only stage data.
- Keep query/kernel read tests passing via Kernel APIs.

Run:
- `julia --project test/runtests.jl`

Acceptance criteria:
- No app-level `Recorder` or `Reader` modules remain.
- `SIMOS` has one active session slot (`worksession`) only.
- Session macros still work with same names.
- Commit clears stage but keeps active session.
- All disk reads/writes remain delegated to Kernel ScopeTapes.

## Assumptions captured from interview text

- “rename later” interpreted as: keep current macro names now.
- “commit cleans staged data” interpreted as: no implicit session-end on commit in this pass.
