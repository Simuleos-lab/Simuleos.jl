# Codebase Relocation — Decisions

**Issue**: Reorganize misplaced code across modules to converge on a clean two-tier architecture (Core primitives vs Workflow globals).

## Architecture Principle

Two tiers of global state:
- **Core globals**: `SimOs` — fundamental system state, available everywhere
- **Workflow globals**: `SessionRecorder` — Recorder-specific, NOT accessed by primitives

Pipeline primitives work at the **object level** (Stage, Scope, SimOs), not raw I/O.
Macros/convenience functions resolve workflow globals and delegate to primitives.

---

## Issue 1: `_find_project_root()` — Duplicate Logic

**From**: `Recorder/session.jl` + inline in `Core/OS.jl`
**To**: New file `Core/project.jl`

**Q**: Where should project path helpers live?
**A**: New `Core/project.jl` — centralizes all project structure paths. `Core/home.jl` narrowed to `~/.simuleos` global home only.

**`Core/project.jl` contents:**
- `find_project_root(start_path)` — shared upward `.simuleos/` search
- `_sessions_dir(root)` — `sessions/` path
- `_session_dir(session)` — `sessions/<label>/` path
- `_tape_path(tape)` — `context.tape.jsonl` path
- `_blob_path(bh)` — `blobs/<sha1>.jls` path
- All path helpers currently in `Core/query/handlers.jl` move here

**`Core/home.jl` keeps only:**
- `_simuleos_dirname()`, `default_home_path()`, `simuleos_dir()`, `project_json_path()`, `global_settings_path()`

---

## Issue 2: `_capture_session_metadata()` → Recorder

**From**: `Core/utils.jl`
**To**: `Recorder/session.jl`
**Rename**: `_capture_recorder_session_metadata`

Only called by `Recorder.session_init()`. Recorder-domain logic.

---

## Issue 3: `_process_scope!()` → Recorder Pipeline

**From**: `Core/scope.jl`
**To**: `Recorder/pipeline.jl` (new file)
**Rename**: `_fill_scope!`

Semantics: receives raw locals/globals, fills the Scope object.

Core primitives it calls stay in Core:
- `Core._is_lite(value)` / `Core._liteify(value)` — `utils.jl`
- `Core._write_blob(root_dir, value)` / `Core._blob_hash(value)` — `blob.jl`

**Signature:**
```julia
function _fill_scope!(scope::Core.Scope, stage::Core.Stage,
                      locals::Dict, globals::Dict,
                      src_file::String, src_line::Int, label::String;
                      simignore_rules::Vector,
                      simos::Core.SimOs)
end
```

---

## Issue 4: Tape Writing → Recorder Pipeline

**From**: `Core/tape.jl` (`_append_to_tape`) + `Core/json.jl` (`_write_commit_record`)
**To**: `Recorder/pipeline.jl`
**Rename**: `write_commit_to_tape`

Works at object level (Stage, Scope). I/O helpers are internal.

**Signature:**
```julia
function write_commit_to_tape(session_label::String, commit_label::String,
                               stage::Core.Stage, meta::Dict;
                               simos::Core.SimOs)
end
```

**JSON serialization** (`_write_json` and all type-specific methods) **stays in Core** — needed by both Reader and Recorder.

---

## Issue 5: `validate_project_folder()` → sys-init.jl

**From**: `Core/OS.jl`
**To**: `Core/sys-init.jl`

Pairs with `sim_init` which creates `project.json`. Keeps OS.jl focused on runtime activation.

---

## Summary of File Changes

| Action | File | Detail |
|---|---|---|
| **Create** | `Core/project.jl` | `find_project_root` + all path helpers from `query/handlers.jl` |
| **Create** | `Recorder/pipeline.jl` | `_fill_scope!`, `write_commit_to_tape` (object-level primitives, `simos` required kwarg) |
| **Narrow** | `Core/home.jl` | Remove `local_settings_path` if project-related, keep only `~/.simuleos` paths |
| **Narrow** | `Core/query/handlers.jl` | Remove path helpers (moved to `project.jl`), keep navigation functions (`sessions()`, `tape()`, `blob()`, `exists()`) |
| **Move** | `Core/utils.jl` → `Recorder/session.jl` | `_capture_session_metadata` → `_capture_recorder_session_metadata` |
| **Move** | `Core/scope.jl` → `Recorder/pipeline.jl` | `_process_scope!` → `_fill_scope!` |
| **Move** | `Core/tape.jl` + `Core/json.jl` → `Recorder/pipeline.jl` | `_append_to_tape` + `_write_commit_record` → `write_commit_to_tape` |
| **Move** | `Core/OS.jl` → `Core/sys-init.jl` | `validate_project_folder` |
| **Update** | `Recorder/macros.jl` | Rewire macros to call `pipeline.jl` primitives |
| **Update** | `Recorder/session.jl` | Remove `_find_project_root`, use `Core.find_project_root` |
| **Update** | `Core/Core.jl` | Include `project.jl`, remove `scope.jl` include, remove `tape.jl` include |
| **Update** | `Recorder/Recorder.jl` | Include `pipeline.jl` |
| **Delete** | `Core/scope.jl` | Content moved to Recorder |
| **Delete** | `Core/tape.jl` | Content moved to Recorder |

## Design Pattern

```
Macros (@session_capture, @session_commit)
  ↓ resolve globals (current_sim[], sim.recorder)
  ↓ unpack workflow state (stage, meta, simignore_rules)
Pipeline (Recorder/pipeline.jl)
  ↓ object-level: _fill_scope!(scope, stage, ...; simos)
  ↓ object-level: write_commit_to_tape(label, ..., stage, meta; simos)
Core primitives
  ↓ _is_lite, _liteify, _write_blob, _write_json
  ↓ find_project_root, path helpers
```
