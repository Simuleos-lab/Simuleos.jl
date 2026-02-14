# Reader Read Capability Inventory

Full inventory of all reading/querying operations in SimuleOs, organized by layer.

---

## Layer 1: Data Structures (Kernel/core/types.jl)

### Handler Types (navigation entry points)

| Type | Fields | Purpose |
|------|--------|---------|
| `RootHandler` | `path::String` | Entry point for querying a .simuleos/ directory |
| `SessionHandler` | `root::RootHandler, label::String` | Points to a session directory |
| `TapeHandler` | `session::SessionHandler` | Points to context.tape.jsonl file |
| `BlobHandler` | `root::RootHandler, sha1::String` | Points to a blob file |

### Record Types (typed data loaded from storage)

| Type | Key Fields | Purpose |
|------|-----------|---------|
| `CommitRecord` | `session_label, commit_label, metadata, scopes, blob_refs` | Typed commit from tape |
| `ScopeRecord` | `label, timestamp, variables, labels, data` | Typed scope from tape |
| `VariableRecord` | `name, src_type, value, blob_ref, src` | Typed variable from tape |
| `BlobRecord` | `data::Any` | Typed blob loaded from disk |
| `SessionReader` | `session_label::Union{Nothing, String}` | Reading state on sim.reader (minimal) |

---

## Layer 2: Path Helpers (Kernel/core/project.jl) — all I0x

| Function | Signature | Purpose |
|----------|-----------|---------|
| `_sessions_dir` | `(root::RootHandler) -> String` | Path to sessions/ directory |
| `_session_dir` | `(session::SessionHandler) -> String` | Path to sessions/<label>/ |
| `_tape_path` | `(tape::TapeHandler) -> String` | Path to context.tape.jsonl |
| `_blob_path` | `(root_dir::String, sha1::String) -> String` | Path to blobs/<sha1>.jls |
| `_blob_path` | `(bh::BlobHandler) -> String` | Overload for handler |
| `find_project_root` | `(start_path::String) -> Union{String, Nothing}` | Search upward for .simuleos/ |

---

## Layer 3: Navigation (Kernel/scopenav/handlers-I1x.jl) — all I1x

| Function | Signature | Purpose |
|----------|-----------|---------|
| `sessions` | `(root::RootHandler) -> Vector{SessionHandler}` | List all sessions in root |
| `tape` | `(session::SessionHandler) -> TapeHandler` | Get tape handler for session |
| `blob` | `(root::RootHandler, sha1::String) -> BlobHandler` | Get blob handler by SHA1 |
| `exists` | `(handler::TapeHandler) -> Bool` | Check if tape file exists |
| `exists` | `(handler::BlobHandler) -> Bool` | Check if blob file exists |

---

## Layer 4: Type Constructors (Kernel/scopenav/loaders-I0x.jl) — all I0x

| Function | Signature | Purpose |
|----------|-----------|---------|
| `_raw_to_variable_record` | `(name::String, raw::Dict) -> VariableRecord` | Dict to typed variable |
| `_raw_to_scope_record` | `(raw::Dict) -> ScopeRecord` | Dict to typed scope |
| `_raw_to_commit_record` | `(raw::Dict) -> CommitRecord` | Dict to typed commit |

---

## Layer 5: Loaders (Kernel/scopenav/loaders-I1x.jl) — all I1x

| Function | Signature | Purpose |
|----------|-----------|---------|
| `iterate_raw_tape` | `(handler::TapeHandler) -> Iterator{Dict}` | Lazy raw JSONL iteration |
| `iterate_tape` | `(handler::TapeHandler) -> Iterator{CommitRecord}` | Lazy typed iteration |
| `Base.collect` | `(::Type{Vector{CommitRecord}}, handler::TapeHandler)` | Eager collection |
| `Base.iterate` | `(handler::TapeHandler)` | Make TapeHandler directly iterable |
| `load_raw_blob` | `(handler::BlobHandler) -> Any` | Deserialize blob data |
| `load_blob` | `(handler::BlobHandler) -> BlobRecord` | Load and wrap blob |

---

## Layer 6: High-Level Access (Reader/Reader-I3x.jl) — I3x

| Function | Signature | Purpose |
|----------|-----------|---------|
| `_get_reader` | `() -> SessionReader` | Get/create reader from SIMOS[].reader |

---

## Current Read Workflows

### Workflow 1: Iterate all commits in a session

```
RootHandler(path) [I0x]
  -> sessions(root) [I1x]
    -> tape(session) [I1x]
      -> for commit in tape_handler [I1x]
           commit::CommitRecord
```

### Workflow 2: Load blob data

```
RootHandler(path) [I0x]
  -> blob(root, sha1) [I1x]
    -> exists(blob_handler) [I1x]
      -> load_blob(blob_handler) [I1x]
           blob_record::BlobRecord
```

### Workflow 3: Raw dict access (no type wrapping)

```
RootHandler(path) [I0x]
  -> SessionHandler(root, label) [I0x]
    -> tape(session) [I1x]
      -> iterate_raw_tape(tape_handler) [I1x]
           raw::Dict{String, Any}
```

---

## Gap Analysis

- **Reader has no I1x interface** — only `_get_reader()` at I3x
- All actual reading logic lives in Kernel/scopenav at I0x/I1x
- No high-level composed operations exist (e.g., "load session by label with resolved blobs")
- `SessionReader` type is near-empty (just `session_label`)

## Integration Level Distribution

- **I0x**: ~24 functions (path helpers, type constructors, utilities)
- **I1x**: ~12 functions (navigation, loading, filesystem)
- **I3x**: 1 function (`_get_reader`)

## Directory Structure Navigated

```
.simuleos/
├── sessions/
│   ├── <label>/
│   │   └── tapes/
│   │       └── context.tape.jsonl
│   └── ...
└── blobs/
    ├── <sha1>.jls
    └── ...
```
