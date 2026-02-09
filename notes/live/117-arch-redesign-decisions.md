# SimuleOs Architecture Redesign — Decisions

Follows from `116-arch-redesign.md`. Decisions made via design interview.

---

## Goal

Create a clean Core model with convenient global state machinery, scalable for incorporating new subsystems. This redesign is about **system organization**, not changing the recording mechanics.

---

## SimOs — The App Object

**Q**: What is SimOs's role?
**A**: SimOs is the glue/app object. It holds all SimuleOs state — project, settings, and references to active subsystems.

**Q**: Should SimOs hold subsystem references?
**A**: Yes. `sim.recorder`, `sim.reader`, and future subsystems live on SimOs. `SimOs` is the single source of truth.

**Q**: Should subsystem state be duplicated (e.g., `root_dir` on SessionRecorder)?
**A**: No. Single source — SessionRecorder references `sim.project` for project-level data. Duplication only as a justified exception.

---

## Initialization — `sim_activate`

**Q**: `sim_init` vs `activate` naming?
**A**: Use `sim_activate`. Replaces both current `activate()` and the doc's `sim_init()`.

**Q**: How does `sim_activate` relate to the global?
**A**: Always works with global state. Mutates/sets `current_sim[]`.

**Q**: What does `sim_activate` do?
**A**: Minimal bootstrapping — init SimOs, resolve project. If project not found, warn (don't error). User can call explicitly to override.

**Q**: Auto-init on `using Simuleos`?
**A**: Yes. `__init__()` auto-detects `.simuleos/` upward from `pwd()` and calls `sim_activate`. User can always overwrite after.

**Q**: Does `sim_activate` accept args/overrides?
**A**: Yes. Same signature as current `activate(path, args)`.

---

## Recording — SessionRecorder

**Q**: What does SessionRecorder own?
**A**: Staging + simignore + settings cache (same as current `Session`, renamed). All are recording concerns.

**Q**: How is a session started?
**A**: `session_init(label)` — creates SessionRecorder, sets `current_sim[].recorder`, uses global `current_sim[]`.

**Q**: Git clean check?
**A**: Stays at session init. Hard error if dirty, no opt-out.

**Q**: How does a session end?
**A**: `@session_commit` closes the session and clears `current_sim[].recorder` automatically.

**Q**: What if macros are called with no active session?
**A**: Error immediately with clear message ("no active session, call @session_init first").

**Q**: Is the recording workflow itself changing?
**A**: No. Staging, scope, capture, commit — same mechanics. Only the system organization changes.

---

## Reading — Handlers + SessionReader

**Q**: What is the core read interface?
**A**: Handler types (`RootHandler`, `SessionHandler`, `TapeHandler`, `BlobHandler`) are the core interface. Not replaced.

**Q**: What about the wrapper types (`CommitWrapper`, `ScopeWrapper`, etc.)?
**A**: They become proper Core types with typed fields (not raw Dict wrappers).

**Q**: Does `SessionReader` exist?
**A**: Yes, but as the global-facing counterpart to SessionRecorder — manages `sim.reader` state. Keep it simple for now, detail later.

**Q**: Multi-project queries?
**A**: Deferred. Out of scope for this redesign.

---

## Module Organization — Core vs Subsystems

**Q**: What goes in Core?
**A**: Tape I/O, blob I/O, JSON serialization, scope processing, record types, query/reader system (handlers, loaders, typed wrappers). This is the reusable data layer.

**Q**: What goes in Recorder module?
**A**: Macros, `session_init`, staging workflow, simignore, global `current_sim[].recorder` management. Recorder is a consumer of Core.

**Q**: Where are types declared?
**A**: Centrally in Core (`types.jl`), even if used by specific subsystems. Subsystem modules are for code organization, not type ownership.

**Q**: Can other subsystems use Core directly?
**A**: Yes. E.g., FileSystem could write to tapes/blobs using Core without going through Recorder.

**Q**: What about `Registry`, `FileSystem`, `Tools`?
**A**: Keep as stubs/placeholders.

---

## Global State

**Q**: How many globals?
**A**: One: `current_sim[]`. No separate `current_session[]`. Active session is `current_sim[].recorder`.

**Q**: How do macros access state?
**A**: Through `current_sim[].recorder` every time.

**Q**: Testing/isolation pattern?
**A**: `set_sim!()` / `reset_sim!()` (like current `set_os!()` / `reset_os!()`).

---

## Naming Conventions

**Q**: Macro prefix?
**A**: `@session_*` (e.g., `@session_capture`, `@session_commit`, `@session_init`).

**Q**: System-level function prefix?
**A**: `sim_*` (e.g., `sim_activate`).

**Q**: Dual API?
**A**: Yes. Functions for programmatic use + macros as convenience wrappers. Same underlying logic.

---

## Summary

```
using Simuleos          # auto: sim_activate() if project detected

sim_activate(path)      # explicit init, sets current_sim[]

@session_init "label"   # creates SessionRecorder on current_sim[].recorder
@session_context ...    # add context to current scope
@session_store vars...  # mark variables for blob storage
@session_capture "label"# snapshot locals/globals
@session_commit         # persist to tape, clears current_sim[].recorder

# Reading — handler-based, not global
root = RootHandler(path)
for session in sessions(root)
    for commit in iterate_tape(tape(session))
        # ...
    end
end
```

### Module Layout (target)

```
Core/
  types.jl          # All types: SimOs, SessionRecorder, SessionReader,
                    #   Stage, Scope, ScopeVariable, Project, ...
                    #   CommitRecord, ScopeRecord, VariableRecord, BlobRecord (typed, not Dict wrappers)
                    #   RootHandler, SessionHandler, TapeHandler, BlobHandler
  OS.jl             # current_sim[], sim_activate(), set_sim!(), reset_sim!()
  tape.jl           # Tape I/O (read + write)
  blob.jl           # Blob I/O (read + write)
  json.jl           # JSON serialization
  scope.jl          # Scope processing (lite detection, variable classification)
  query/            # Handlers, loaders, iterators
  ...

Recorder/
  macros.jl         # @session_init, @session_capture, @session_commit, etc.
  session.jl        # session_init(), staging workflow
  simignore.jl      # Variable filtering rules

Reader/
  (simple for now — SessionReader global management)

Registry/           # stub
FileSystem/         # stub
Tools/              # stub
```
