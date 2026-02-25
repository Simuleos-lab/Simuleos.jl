# 565 — SQLite Index System Mechanics Summary (Phase 4B)

**Date:** 2026-02-25
**Status:** Implemented summary (current state through Phase 4B)
**Scope:** End-to-end summary of the Simuleos SQLite metadata indexing/query system mechanics, including public SQL surface, refresh/rebuild behavior, generic tape catalog, and scope adapter integration

---

## Purpose

This note summarizes the current SQLite metadata indexing system in Simuleos as implemented through:

- Phase 1: metadata rebuild
- Phase 2: incremental refresh + drift fallback
- Phase 3: public SQL view layer (`v_*`)
- Phase 4A: generic tape catalog (`v_tape_*`)
- Phase 4B: scope indexing routed through a registered subsystem adapter

This is a mechanics summary (how it works now), not a design proposal.

---

## Core Model

### SSOT vs derived index

- Raw tapes and blobs are the source of truth (SSOT).
- SQLite metadata index is derived and disposable.
- SQL is the primary user query interface for metadata/provenance.
- Tape/blob iteration remains the lower-level SSOT access path (mostly internal for querying workflows).

### What the SQLite index is for

- discovery (what sessions/commits/scopes/tapes exist)
- filtering (labels, commit labels, source file, metadata keys, variable inventory)
- provenance (file/line, tape order, blob refs)
- stable SQL views as a public query surface

### What the SQLite index does not do (by default)

- deserialize blob payloads
- replace tape/blob SSOT semantics
- invent a new query language

---

## User-Facing Query Surface

### A. Direct API (function surface)

Public functions on `Simuleos`:

- `sqlite_index_path(...)`
- `sqlite_index_open(...)`
- `sqlite_index_rebuild!(...)`
- `sqlite_index_refresh!(...)`

Use when working directly in Julia code without `@simos`.

### B. `@simos sqlite.*` macro surface (common user workflow)

Thin wrappers over the SQLite metadata index:

- `@simos sqlite.path()`
- `@simos sqlite.open(; sync=:none|:refresh|:rebuild)`
- `@simos sqlite.current()`
- `@simos sqlite.execute(sql)`
- `@simos sqlite.execute(sql, params)`
- `@simos sqlite.refresh()`
- `@simos sqlite.rebuild()`
- `@simos sqlite.close()`

Important mechanics:

- `@simos sqlite.execute(...)` is only a wrapper around `SQLite.DBInterface.execute(...)`.
- SQL remains the query language.
- The open SQLite DB handle is cached in `SIMOS` and closed on `sim_reset!` / `@simos system.reset(...)`.

### C. Public SQL contract = `v_*` views

Users should query the documented views, not normalized storage tables.

Current public SQL views:

- Generic tape catalog:
  - `v_tapes`
  - `v_tape_records`
  - `v_tape_index_state`

- Scope subsystem:
  - `v_sessions`
  - `v_commits`
  - `v_scope_inventory`
  - `v_scope_labels_flat`
  - `v_scope_vars_inventory`
  - `v_scope_meta_inventory`

Reason:

- internal normalized tables can evolve
- views are the stable user query interface

---

## Database Structure (current)

### 1. Manifest / DB identity

Table:
- `index_manifest`

Role:
- records schema version / index kind / project root / `.simuleos` path
- used to validate refresh compatibility

### 2. Generic tape catalog (Layer A0; cross-subsystem)

Tables:

- `subsystems`
  - registered SQLiteIndex adapters (`scope` today)

- `tapes`
  - canonical tape inventory (subsystem, owner, role, path, relpath, seen state)

- `tape_records`
  - generic tape-row metadata catalog
  - one row per record with record order, file/line provenance, type, writer, timetag, record hash

- `tape_index_state`
  - per-tape incremental refresh checkpoint
  - last indexed record order + last record provenance/hash + refresh mode

These tables are generic and do not encode scope-specific semantics.

### 3. Scope subsystem projection tables (Layer A1)

Current scope-specific tables (still used and still valid):

- `sessions`
- `session_labels`
- `session_index_state`
- `commits`
- `scopes`
- `scope_labels`
- `scope_vars`
- `scope_meta_kv`

These are typed metadata projections for the scope subsystem.

---

## Rebuild / Refresh Mechanics

## Rebuild (`sqlite_index_rebuild!`)

High-level sequence:

1. Resolve DB path and remove old DB file (if present)
2. Create fresh SQLite DB
3. Create core schema (`index_manifest`, generic catalog tables)
4. Create adapter-provided subsystem schemas (scope tables today)
5. Insert manifest
6. Register built-in subsystems in `subsystems`
7. Run adapter rebuild indexing hooks (scope rebuild hook today)
8. Recreate public SQL views (`v_tape_*` + adapter views)
9. Touch manifest `updated_at`
10. Close DB

Properties:

- deterministic rebuild from tapes
- no blob payload deserialization by default

## Refresh (`sqlite_index_refresh!`)

High-level sequence:

1. If DB missing -> rebuild
2. Open DB
3. Validate refresh capability:
   - manifest matches project root / `.simuleos` dir
   - core generic tables exist
   - adapter-required tables exist
4. If not refresh-capable -> rebuild fallback
5. Begin transaction
6. Register built-in subsystems
7. Run adapter refresh hooks (scope refresh hook today)
8. Recreate public views
9. Touch manifest `updated_at`
10. Commit
11. If drift error was raised -> rebuild fallback

Fallback policy (current):

- drift detection in indexed tapes triggers full DB rebuild fallback

---

## Drift Detection Mechanics (current)

Drift detection currently happens in the scope subsystem refresh path, using two prefix checks:

### A. Scope commit-prefix verification (scope projection integrity)

During incremental refresh of a scope tape:

- previously indexed commit prefix is re-read from tape
- indexed `commits` row is verified against current tape record metadata:
  - commit UID
  - commit label
  - tape record order
  - tape file
  - tape line

Mismatch => drift error => rebuild fallback.

### B. Generic tape-record prefix verification (generic catalog integrity)

During incremental refresh:

- previously indexed generic `tape_records` prefix is re-read and checked
- current tape row is verified against indexed row:
  - record type
  - writer
  - timetag
  - file path / line
  - record hash

Mismatch => drift error => rebuild fallback.

This ensures the generic tape catalog and scope-specific projection stay consistent.

---

## Scope Adapter Mechanics (Phase 4B)

### Why Phase 4B exists

Phase 4A introduced the generic tape catalog, but the core still called scope-specific schema/view/index logic directly.

Phase 4B refactors this into an internal adapter model so scope is routed through a registry and can later be joined by blobstorage and other tape-producing subsystems.

### Current adapter registry shape

`SQLiteIndex` now has an internal registry (currently one adapter):

- scope adapter (`subsystem_id = "scope"`)

The registry drives:

- subsystem schema creation
- subsystem rebuild indexing
- subsystem refresh indexing
- subsystem view recreation
- refresh-capability required-table checks
- subsystem registration row in `subsystems`

### Scope adapter responsibilities (current)

The scope adapter currently provides hooks for:

- `create_schema!`
- `rebuild_index!`
- `refresh_index!`
- `recreate_views!`

It also declares:

- `subsystem_id`
- `adapter_version`
- `required_tables`
- `drop_view_names`

### What is still centralized in `SQLiteIndex.jl`

The actual scope parsing/indexing internals are still in `SQLiteIndex.jl` (by design for the phase boundary):

- session scanning
- session tape indexing (rebuild / refresh)
- scope table writes
- scope/generic checkpoint updates

So Phase 4B is the routing refactor (registry + hooks), not the full extraction of all scope indexing internals into adapter-only files.

---

## Generic Tape Catalog Population (current scope-only implementation)

Phase 4A/4B populate the generic catalog from the scope subsystem only (no blob adapter yet).

Mechanics during scope tape scan:

1. Build deterministic scope tape identity (`tape_uid`)
   - based on subsystem namespace + project-relative tape path

2. Upsert `tapes` row
   - subsystem = `scope`
   - logical owner = `session_id`
   - tape role = `main`
   - tape path + relpath

3. For each tape record encountered
   - insert row into `tape_records`
   - include record order, type, writer, timetag, file/line, record hash

4. Update `tape_index_state`
   - last indexed record order
   - last file/line
   - last record hash
   - refresh mode (`rebuild` / `incremental`)

5. In parallel, populate/update scope projection tables (`sessions`, `commits`, `scopes`, ...)

This gives a generic A0 catalog and subsystem A1 projection from one scan pass.

---

## View Layer Mechanics

### Generic views (`v_tape_*`)

Purpose:

- expose cross-subsystem catalog and refresh state
- support discovery and diagnostics independent of scope schema

Current views:

- `v_tapes`
  - joins `tapes` with `tape_index_state`
  - includes record counts and refresh checkpoint fields

- `v_tape_records`
  - joins `tape_records` with `tapes`
  - includes subsystem + logical owner + tape provenance + record metadata

- `v_tape_index_state`
  - joins `tape_index_state` with `tapes`
  - exposes checkpoint state with tape identity/context

### Scope views (`v_scope_*`, `v_sessions`, `v_commits`)

Purpose:

- stable, ergonomic SQL surface for scope-query workflows
- avoid exposing normalized scope tables as the user-facing contract

Examples:

- `v_scope_labels_flat` for label-based filtering (`main.sample`, etc.)
- `v_scope_vars_inventory` for variable inventory / `blob_ref` lookup
- `v_scope_meta_inventory` for metadata-key filtering
- `v_scope_inventory` for one-row-per-scope provenance summary

### View recreation policy

Views are recreated on:

- rebuild
- refresh

This is intentional:

- guarantees the public SQL surface exists even if a user drops a view manually
- allows internal view definitions to evolve in sync with code

---

## Refresh Capability Checks (what makes an index “refreshable”)

Before refresh proceeds incrementally, the DB must match:

1. Manifest compatibility
- `schema_version`
- `index_kind`
- `project_root`
- `simuleos_dir`

2. Core generic tables exist
- `index_manifest`
- `subsystems`
- `tapes`
- `tape_records`
- `tape_index_state`

3. Adapter-required tables exist
- scope adapter declares its table set (`sessions`, `commits`, `scopes`, etc.)

If any check fails:

- refresh falls back to rebuild

This enables in-place migration behavior when the schema evolves.

---

## Querying Workflow (recommended)

### User path (metadata / provenance)

1. Open index via `@simos sqlite.open(; sync=:refresh)`
2. Query public views with `@simos sqlite.execute(...)`
3. Filter/discover rows and provenance in SQL
4. Hydrate blobs later only when needed (outside SQLite index)

### Example (scope label filter via public view)

```julia
@simos sqlite.open(; sync=:refresh)

rows = @simos sqlite.execute("""
    SELECT scope_uid, commit_label, src_file, src_line
    FROM v_scope_labels_flat
    WHERE session_id = ? AND scope_label = 'main.sample'
    ORDER BY commit_ord, scope_ord
""", (session_id,))
```

### Example (generic tape discovery)

```julia
rows = @simos sqlite.execute("""
    SELECT subsystem_id, logical_owner_id, tape_role, record_count, refresh_mode
    FROM v_tapes
    ORDER BY subsystem_id, logical_owner_id
""")
```

---

## Current Limits (important)

1. Only the scope subsystem is implemented as an adapter
- generic tape catalog is populated from scope tapes only
- blobstorage adapter is not implemented yet

2. Scope indexing internals are not fully extracted
- Phase 4B routes through adapter hooks
- full extraction of scope indexing internals can happen later without changing the adapter contract

3. SQL index is metadata-oriented
- blob payload deserialization is intentionally outside the index path

4. Generic refresh orchestration is adapter-driven, but drift fallback is still global
- any detected drift currently rebuilds the whole DB

---

## Mental Model (short version)

- **Tapes/blobs are the truth**
- **SQLite is the derived metadata warehouse**
- **`v_*` views are the public SQL API**
- **Adapters make subsystems first-class**
- **Scope is no longer special in the index architecture (but currently the only implemented adapter)**

---

## Next Step (after this summary)

Phase 4C:

- implement blobstorage adapter
- populate generic tape catalog from blob tapes too
- add first `v_blob_*` views

That is the first real test that the Phase 4B adapter architecture is doing its job.

