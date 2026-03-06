# 584 — Naming Glossary & Conventions

> Source: M3 from codebase quality review (573–581 series).
> Scope: `src/` Julia codebase.

---

## Abbreviation Glossary

| Abbreviation | Full Name              | Usage Context                          |
|--------------|------------------------|----------------------------------------|
| `sim`        | `SimOs`                | Parameter & local variable name        |
| `ws`         | `WorkSession`          | Parameter & local variable name        |
| `proj`       | `SimuleosProject`      | Parameter & local variable name        |
| `gh`         | `GitHandler`           | Parameter & local variable name        |
| `meta`       | metadata dict          | Local variable name                    |
| `raw`        | raw data dict          | Local variable name                    |

### Module Aliases (const at module level)

| Alias   | Module         | Defined In                        |
|---------|----------------|-----------------------------------|
| `_Krn`  | `Kernel`       | `WorkSession/WorkSession.jl`      |
| `_WS`   | `WorkSession`  | `WorkSession/WorkSession.jl`      |
| `_SQLi` | `SQLiteIndex`  | `SimosAPI/macro.jl`               |
| `_API`  | `SimosAPI`     | `SimosAPI/macro.jl`               |

---

## Naming Rules

### 1. Public vs Internal

- **Public API**: No underscore prefix. Use descriptive names.
  - `scope_capture()`, `session_commit()`, `settings()`
- **Internal helpers**: Single underscore prefix `_`.
  - `_session_metadata_base()`, `_shared_key()`
- **Module-private constants**: Single underscore prefix.
  - `_SCOPE_CLASS_SPEC`, `_SIMOS_LIFECYCLE_READY`

### 2. Helper Function Style: `_verb_noun` or `_domain_verb_noun`

Pattern: `_[domain_]verb_noun[!]`

```
_encode_scope_vars_record()      # domain=scope, verb=encode, noun=vars_record
_decode_snap_scope_record()      # domain=snap_scope, verb=decode, noun=record
_session_init_git_dirty_policy() # domain=session_init, noun=git_dirty_policy
_settings_stack_rebuild!()       # domain=settings_stack, verb=rebuild
```

Domain-prefix grouping is encouraged for related helpers:
```
_shared_*     → shared scope helpers
_session_*    → session lifecycle helpers
_blob_*       → blob storage helpers
_tape_*       → tape I/O helpers
_fragment_*   → tape fragment helpers
_settings_*   → settings stack helpers
_ctx_hash_*   → context hash helpers
_remember_*   → cache remember macro helpers
_cache_*      → cache runtime helpers
```

### 3. Parameter Names

- Use abbreviations from the glossary for parameters and locals.
- **Current state**: `simos` is used in ~45 function signatures across Kernel and WorkSession.
  This should migrate to `sim` incrementally (file-by-file, during related refactors).
- `project_root::String` is acceptable in SQLiteIndex where the value is a path string,
  not a `SimuleosProject` object — distinguish by type.

### 4. Struct Field Names

- Struct fields use full words: `worksession`, `project_root`, `blobstorage`.
- These are stable API and should NOT be abbreviated.

### 5. Encode/Decode Symmetry

Always pair: `encode_<class>_record` / `decode_<class>_record`.

Internal helpers for collections use `_encode_<domain>_vars_record` (abbreviated `vars`).

### 6. Constants

- Public constants: `SCREAMING_SNAKE_CASE` without underscore prefix.
  - `CLASS_SPEC_SNAP_SCOPE`, `LITE_TYPES`
- Private constants: `_SCREAMING_SNAKE_CASE` with underscore prefix.
  - `_SCOPE_CLASS_ID`, `_SANDBOX_MARKER_FILE`

---

## Incremental Migration Notes

### `simos` → `sim` parameter rename

277 occurrences across 31 files. Migrate file-by-file during related work:

**Priority files** (most occurrences):
1. `Kernel/Infra/settings/sources.jl` (~24 uses)
2. `Kernel/Infra/settings/stack.jl` (~29 uses)
3. `WorkSession/session.jl` (~28 uses)
4. `Kernel/Infra/settings/registry.jl` (~6 uses)

**Already using `sim`** (no change needed):
- `Kernel/Foundation/state.jl`
- `WorkSession/settings.jl`
- `WorkSession/simignore.jl`

---

## Applied Fixes (this session)

1. Removed dead code: `_type_short` (unused wrapper in `utils.jl:11`)
2. Removed dead code: `_rule_str` (unused debug helper in `simignore.jl:8-11`)
3. Renamed `_encode_scope_variables_record` → `_encode_scope_vars_record` (3 call sites + definition)
