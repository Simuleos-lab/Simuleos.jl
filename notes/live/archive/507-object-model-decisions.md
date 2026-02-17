# Object Model Refactor - Decisions

**Source**: Design interview on `106-architecture-objects.md`

---

## Scope Lifecycle

**Q**: How should `ScopeContext` relate to `Scope`?
**A**: Eliminate `ScopeContext` as a separate type. Flatten all fields directly into `Scope`. The stage always has a "current open scope" that gets populated incrementally.

**Q**: What is the new lifecycle?
**A**:
1. `@sim_session` → Creates `Session` with `Stage` containing one empty, open `Scope`
2. `@sim_context` / `@sim_store` → Modifies the current open `Scope` directly
3. `@sim_capture` → Finalizes current `Scope` (sets `isopen = false`, captures variables), then creates a new empty open `Scope`
4. `@sim_commit` → Writes all closed scopes to tape, clears stage

**Q**: At commit time, what happens to the open scope?
**A**: Error if open scope has pending context data. Force explicit capture.

---

## Stage Structure

**Q**: Should `current_scope` be a separate field or just `scopes[end]`?
**A**: Separate field for clarity.

**Q**: Should `blob_refs::Set{String}` remain on Stage?
**A**: Remove it. Blobs are written at `@sim_capture` time (deduplication happens at write). Derive blob refs from variables when needed. Single source of truth.

**Final Stage structure**:
```julia
mutable struct Stage
    scopes::Vector{Scope}      # closed scopes
    current_scope::Scope       # the open scope being populated
end
```

---

## Scope Structure

**Q**: Keep `timestamp` on Scope or use commit time?
**A**: Keep per-scope `timestamp` for now. Reconsider later if unnecessary.

**Q**: Where should source location (file, line) and threadid live?
**A**: In `data` dict as default context entries (`:src_file`, `:src_line`, `:threadid`). Same place users can add custom context.

**Q**: Rename `type` to `type_str` and truncate?
**A**: Yes. `type_str = first(string(typeof(var)), 25)`. Guard against large type signatures.

**Q**: Keep `blob_set` naming?
**A**: Yes. Mechanism unchanged, only refactoring object structure.

**Final Scope structure**:
```julia
struct Scope
    label::String
    timestamp::DateTime
    isopen::Bool
    variables::Dict{String, ScopeVariable}
    labels::Vector{String}           # from @sim_context "label"
    data::Dict{Symbol, Any}          # from @sim_context :key => val (includes src_file, src_line, threadid)
    blob_set::Set{Symbol}            # markers from @sim_store
end
```

---

## ScopeVariable Structure

**Q**: Rename `type` field?
**A**: Rename to `type_str`. Truncated to 25 chars, documentation only.

```julia
struct ScopeVariable
    name::String
    type_str::String                 # first(string(typeof(var)), 25)
    value::Union{Nothing, Any}
    blob_ref::Union{Nothing, String}
    src::Symbol                      # :local or :global
end
```

---

## Session Structure

**Q**: Where does `current_context` live?
**A**: Removed. Context now lives directly in `Stage.current_scope`.

```julia
mutable struct Session
    label::String
    root_dir::String
    stage::Stage
    meta::Dict{String, Any}
end
```

---

## Summary

- `ScopeContext` eliminated - fields flattened into `Scope`
- `Stage.blob_refs` removed - derive from variables
- `Stage.current_scope` added as explicit field
- `Scope.isopen` added for lifecycle tracking
- `ScopeVariable.type` renamed to `type_str` (truncated)
- Source location captured as default context data
