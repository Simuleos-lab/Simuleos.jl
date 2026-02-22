## Simuleos Glossary

### Simuleos
— An Operative System for simulation management in Julia.

### Session label
— User-provided global label attached to a run via `@sim_session`.

### Global runtime state
— Process-wide mutable state tracking the active run and current stage accumulation.

### Stage
— The in-memory accumulation of captured scopes since the last commit.

### Stage stack
— Ordered list of captured scopes in the current stage (each capture pushes one).

### Commit
— The operation that persists the current stage as a new append-only stage record and clears the stage.

### Append-only log
— The storage principle: never edit, only add new run/stage/scope/blob records.

### Context
— The information required to understand what happened during the simulation.

### Scope (concept)
— A snapshot of “what’s in Julia scope” at a capture point.

### `Scope` (struct)
— Dictionary-like mapping from variable names to their captured descriptions.

### Scope snapshot
— The act/result of extracting the current local scope into a `Scope`.

### ScopeVariable (concept)
— A per-variable entry describing what a variable is and optionally its value/link.

### `ScopeVariable` (struct)
— Holds `name/type/kind/summary` always, plus `value` (lite) or `blob_ref` (requested).

### Descriptor
— The always-stored metadata for a variable (type + summary, etc.), even when value isn’t stored.

### Lite value
— A JSON-primitive equivalent (Bool/Number/String/nothing/missing) stored inline in context JSON.

### Non-lite value
— Anything not lite (arrays, matrices, structs, functions), described but not stored by default.

### Lite policy
— The MVP rule defining exactly which Julia values are considered lite.

### JSON context blob
— The plain JSON artifact storing a scope snapshot (descriptors + any lite values + blob refs).


### Explicit store request
— The user’s signal that a non-lite variable should be stored as a blob (via `@sim_store`).

### Store set
— The global set of variable names marked by `@sim_store` for blob creation on capture.

### Blob
— Serialized heavy/non-lite data stored separately from JSON context.

### Blob storage backend (hardcoded)
— The MVP’s fixed mechanism/path format for writing blobs.

### Blob reference (`blob_ref`)
— A link/pointer from a scope variable to its stored blob artifact.

### Capture-time blob materialization
— Design rule: blobs are written during `@sim_capture`, not during commit.

### Unlinked blobs
— Blobs created at capture that may never get referenced by a committed stage.

### Garbage collection (future)
— Later system to prune unlinked blobs safely.

### Macros API
— The user-facing commands embedded in scripts: `@sim_session`, `@sim_capture`, `@sim_store`, `@sim_commit`.

### `@sim_session`
— Initializes a run (session label) and clears stage state.

### `@sim_capture`
— Snapshots current local scope, writes requested blobs, pushes scope onto stage stack.

### `@sim_store`
— Marks variable names to be blobbed on the next capture(s) if non-lite.

### `@sim_commit`
— Persists stage record (scopes + links) and clears stage stack.

### Non-invasive guarantee
— The requirement that adding Simuleos shouldn’t force major refactors to existing scripts.

### Scoperias (reference)
— A guiding example for scope extraction and representation patterns.

### Local-scope boundary
— The rule that capture reads the current function/local scope (not arbitrary globals), unless changed later.

### Reproducibility fingerprint
— Capturable environment info (versions, git state, etc.) to help interpret runs (details TBD for MVP).
