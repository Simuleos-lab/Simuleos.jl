# Simuleos Architecture - Object Model

## Core Data Structures

### Global State
```
__SIM_SESSION__: Union{Nothing, Session}
```
Single global variable holding the active recording session.

---

### Session (mutable)
Top-level container for a recording session.

**Fields:**
- `label::String` - User-provided session name
- `root_dir::String` - Path to `.simuleos/` directory
- `stage::Stage` - Accumulates scopes between commits
- `meta::Dict{String, Any}` - Session metadata (git, Julia version, etc.)
- `current_context::ScopeContext` - Per-scope context (reset after each capture)

**Lifecycle:**
- Created by `@sim_session`
- Mutated by `@sim_capture` (adds scopes to stage)
- Persisted by `@sim_commit` (writes stage to disk, then clears it)

---

### Stage (mutable)
Temporary collection of scopes pending commit.

**Fields:**
- `scopes::Vector{Scope}` - Captured scopes waiting to be written
- `blob_refs::Set{String}` - SHA1 hashes of all blobs referenced in this stage

**Lifecycle:**
- Populated by `@sim_capture` (appends new `Scope`)
- Cleared by `@sim_commit` (after writing to tape)

---

### Scope (immutable)
Snapshot of program state at a specific point.

**Fields:**
- `label::String` - User-provided capture label
- `timestamp::DateTime` - When this scope was captured
    - `#FEEDBACK` 
        - eliminate this, we will rely on the timestamp at commit time
- `variables::Dict{String, ScopeVariable}` - All captured variables (locals + globals)
- `context_labels::Vector{String}` - Descriptive tags from `@sim_context`
- `context_data::Dict{Symbol, Any}` - Key-value metadata from `@sim_context`
    - `#FEEDBACK` 
        - we need to add as minimal context data
            - the src file and line number where the capture was invoked
            - this can be obtained via `@__FILE__` and `@__LINE__`
            - the threadid where the capture was invoked

**Created by:**
- `_process_scope()` during `@sim_capture`

---

- `#FEEDBACK`
    - ok, explain me breafly the use of `ScopeContext` at a `Session`
    - is this required because the Scope will not be created till `@sim_capture`? is this redundant at 
    - then is
        ```
        - `context_labels::Vector{String}` - Descriptive tags from `@sim_context`
        - `context_data::Dict{Symbol, Any}` - Key-value metadata from `@sim_context`
        ```
        substituable by a `ScopeContext` object?
        - just reuse the `ScopeContext` object at `Session` level and move it to `Scope` at `@sim_capture` time?
    
---

### ScopeVariable (immutable)
Represents a single variable in a scope.

**Fields:**
- `name::String` - Variable name
- `type::String` - Type as string (for JSON serialization)
    - `#FEEDBACK` 
        - we should truncate this to a short string, not the full type tree
        - no formatting, something like `first(typeof(var), 25)`
        - this is for documentation only, not for reconstruction
        - rename to `type_str`
- `value::Union{Nothing, Any}` - Actual value if "lite", otherwise `nothing`
- `blob_ref::Union{Nothing, String}` - SHA1 hash if stored as blob, otherwise `nothing`
- `src::Symbol` - `:local` or `:global`

**Classification:**
- **Lite**: `value` is set, `blob_ref` is `nothing` (JSON-serializable types)
- **Blob**: `blob_ref` is set, `value` is `nothing` (complex types via `@sim_store`)
- **Type-only**: Both `value` and `blob_ref` are `nothing` (type recorded, data skipped)

---

### ScopeContext (mutable)
Temporary context for the next capture, reset after each `@sim_capture`.
    - `#FEEDBACK`
    - Upgrade semantically to a place where to store context data that is not at the scope variable level
    - call it `MetaContext` or similar?
    - reuse it where required

**Fields:**
- `labels::Vector{String}` - Descriptive labels from `@sim_context "label"`
- `data::Dict{Symbol, Any}` - Key-value pairs from `@sim_context :key => val`
- `blob_set::Set{Symbol}` - Variable names marked by `@sim_store` for blob storage

**Lifecycle:**
- Modified by `@sim_context` and `@sim_store`
- Consumed by `@sim_capture` (copied into the new `Scope`)
- Reset to empty after each `@sim_capture`

---

## Data Classification

### Lite Types
`Union{Bool, Int, Float64, String, Nothing, Missing, Symbol}`

JSON-serializable primitives stored inline in the tape.

### Blob Types
Everything else. Serialized to `.jls` files, referenced by SHA1 hash.

---

## Object Relationships

```
__SIM_SESSION__ (global)
    └─> Session
         ├─> meta: Dict (captured once at session start)
         ├─> current_context: ScopeContext (transient, reset per capture)
         └─> stage: Stage
              ├─> scopes: Vector{Scope}
              │    └─> [Scope, Scope, ...]
              │         ├─> variables: Dict{String, ScopeVariable}
              │         │    └─> [ScopeVariable, ScopeVariable, ...]
              │         ├─> context_labels: Vector{String}
              │         └─> context_data: Dict{Symbol, Any}
              └─> blob_refs: Set{String} (SHA1 hashes)
```

- `#FEEDBACK`
- I think we can reuse `ScopeContext`
- And also, move it to Stage level?
```
__SIM_SESSION__ (global)
    └─> Session
        ├─> meta: Dict (captured once at session start)
        └─> stage: Stage
            ├─> scopes: Vector{Scope}
            ├─> current_context: ScopeContext (transient, reset per capture)
            │    └─> [Scope, Scope, ...]
            │         ├─> variables: Dict{String, ScopeVariable}
            │         │    └─> [ScopeVariable, ScopeVariable, ...]
            │         └─> current_context: ScopeContext (linked at capture from Stage)
            └─> blob_refs: Set{String} (SHA1 hashes)
```


---

## File System Output

### Tape File
`.simuleos/sessions/<label>/tapes/context.tape.jsonl`

JSONL format (one commit per line):
```json
{
  "type": "commit",
  "session_label": "...",
  "metadata": {...},
  "scopes": [...],
  "blob_refs": [...]
}
```

### Blob Store
`.simuleos/blobs/<sha1>.jls`

Content-addressed `.jls` files (serialized Julia objects).
Global store shared across all sessions.

---

## Data Flow Summary

1. **`@sim_session`** → Creates `Session`, captures metadata
2. **`@sim_context`** → Modifies `session.current_context`
3. **`@sim_store`** → Adds symbols to `session.current_context.blob_set`
4. **`@sim_capture`** → Creates `Scope`, appends to `session.stage.scopes`, resets context
5. **`@sim_commit`** → Serializes `session.stage` to tape, writes blobs, clears stage
