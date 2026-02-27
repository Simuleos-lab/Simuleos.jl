# 564 — Multi-Subsystem Tape Index + SQL Surface Plan

**Date:** 2026-02-25
**Status:** Planned
**Scope:** Simuleos architecture plan for scaling SQLite metadata querying beyond scope recording to all tape-producing subsystems

---

## Goal

Generalize the current SQLite metadata index and query surface so it works across multiple Simuleos subsystems that produce tapes.

Primary example today:
- scope recording subsystem (session/commit/scope tapes)

Existing second producer (must fit the same model):
- blobstorage metadata tapes

Target outcome:
- SQL is the main user query interface for metadata/provenance across subsystems
- raw tape/blob readers remain SSOT backend interfaces
- scope subsystem is not a special case in index architecture

---

## Core Decisions (accepted)

1. Raw tapes/blobs are SSOT
- SQLite metadata index is derived/disposable
- rebuild and incremental refresh must be deterministic

2. SQL is the main user query interface
- no new Simuleos query language
- `@simos sqlite.execute(...)` is the common entrypoint

3. Scope recording is one subsystem among many
- scope-specific tables/views are allowed, but must sit on top of a generic tape indexing architecture

4. Expressivity belongs to tape content
- users expand query power by recording more metadata into tapes
- index/query layer should not invent semantics missing from tapes

---

## Problem (current architecture gap)

Current `SQLiteIndex` implementation is functionally useful, but structurally scope-centric:

- refresh state is keyed by `session_id`
- core indexing loop is specialized for scope commit tapes
- public SQL views (`v_scope_*`) expose only scope subsystem data

This creates a scaling problem:
- adding blobstorage tape querying would duplicate refresh/catalog logic
- users would get inconsistent query patterns across subsystems
- kernel reader surfaces remain implicit rather than subsystem-scoped

---

## Design Direction

Split indexing into two layers inside one SQLite DB:

### Layer A0 — Generic Tape Catalog (cross-subsystem)

Purpose:
- canonical metadata/provenance catalog for all tapes and tape records
- shared refresh checkpoints and drift detection primitives

Characteristics:
- subsystem-agnostic
- metadata-only (no blob payload deserialization by default)
- append-only refresh semantics where possible

### Layer A1 — Subsystem Projections (typed metadata)

Purpose:
- typed metadata tables/views for each subsystem
- optimized, ergonomic SQL for each subsystem

Examples:
- scope subsystem: sessions/commits/scopes/scope_vars/...
- blob subsystem: blob metadata events / blob latest metadata / blob refs / ...

Public SQL interface:
- stable `v_*` views (namespaced by subsystem where relevant)

---

## Architecture Principles

1. Generic first, subsystem second
- generic tape catalog provides shared provenance and refresh mechanics
- subsystem indexers consume generic tape records (or equivalent tape iteration context)

2. Stable public SQL views, mutable internal tables
- users query `v_*` views, not normalized storage tables
- internal schema can evolve without breaking user queries

3. Kernel surfaces must be explicit per subsystem
- generic tape primitives in `Kernel`
- typed reader/writer interfaces in subsystem modules

4. Incremental refresh is per tape (not universally per session)
- scope can still maintain `session` summaries/views
- core refresh state should be tape-oriented

---

## Proposed Kernel Organization

### A. Generic tape kernel surface (SSOT primitives)

Keep / formalize in `Kernel`:
- `TapeIO`
- JSONL record iteration with context (`file`, `line_no`)
- generic tape discovery (`project -> all tapes`)
- generic tape identity normalization (subsystem + logical tape key + path)

Suggested API direction (names can change):
- `Kernel.discover_tapes(project_driver; subsystem=nothing)`
- `Kernel.each_tape_records(tape_ref_or_path)`
- `Kernel.each_tape_records_filtered(...)`

### B. Subsystem-specific tape modules (typed readers/writers)

Each subsystem gets a clear typed surface:

- `Kernel.ScopeTapes.*` (already conceptually present)
  - commit/scope tape parsing
  - typed commit/scope iteration

- `Kernel.BlobTapes.*` (new)
  - blob metadata tape record parsing
  - typed blob metadata event iteration

Future subsystems:
- follow same pattern (`Kernel.<Subsystem>Tapes`)

### C. User-facing reader modules (optional per subsystem)

Examples:
- `ScopeReader` (already exists)
- future `BlobReader` (if/when blob metadata query API beyond SQL is useful)

Rule:
- these are typed convenience APIs
- SQL remains the main metadata discovery/query surface

---

## Proposed SQLiteIndex Organization (extensible)

### 1. Subsystem registry (internal)

Introduce a registry of tape-producing subsystems for SQLite indexing.

Each registered subsystem provides:
- `subsystem_id::String` (e.g. `"scope"`, `"blobstorage"`)
- tape discovery function for project
- record filter/parser function(s)
- schema contribution (tables)
- indexing callback (records -> subsystem tables)
- public view contribution (`v_scope_*`, `v_blob_*`, etc.)
- refresh strategy hooks (optional subsystem-level summaries/checkpoints)

This avoids hardcoding subsystem logic into the top-level refresh loop.

### 2. SQLiteIndex phases by responsibility

- **Core catalog module**
  - generic tables (`subsystems`, `tapes`, `tape_records`, `tape_index_state`)
  - refresh orchestration
  - drift detection fallback policy

- **Subsystem adapters**
  - scope adapter (migrates current scope indexing logic)
  - blobstorage adapter (new)

- **Public view builder**
  - recreates stable views after rebuild/refresh
  - composed from core generic views + subsystem-specific views

---

## Proposed Generic SQLite Tables (Layer A0)

These tables are the cross-subsystem backbone and should not encode scope-specific semantics.

### `subsystems`

Purpose:
- declare installed/indexed subsystem adapters

Suggested columns:
- `subsystem_id TEXT PRIMARY KEY`
- `adapter_version TEXT NOT NULL`
- `enabled INTEGER NOT NULL`

### `tapes`

Purpose:
- canonical inventory of all discovered tapes

Suggested columns:
- `tape_uid TEXT PRIMARY KEY`
- `subsystem_id TEXT NOT NULL`
- `project_root TEXT NOT NULL` (optional denorm for diagnostics)
- `logical_owner_id TEXT` (e.g. session_id for scope tapes; nullable/generic)
- `tape_role TEXT` (e.g. `main`, `metadata`, etc.)
- `tape_path TEXT NOT NULL`
- `tape_relpath TEXT`
- `exists_on_disk INTEGER NOT NULL`
- `last_seen_at TEXT NOT NULL`

Indexes:
- `(subsystem_id)`
- `(subsystem_id, logical_owner_id)`
- `(tape_path)`

### `tape_records`

Purpose:
- generic metadata catalog of tape rows for all subsystems

Suggested columns:
- `tape_uid TEXT NOT NULL`
- `record_ord INTEGER NOT NULL`
- `record_type TEXT`
- `writer TEXT`
- `timetag TEXT`
- `file_path TEXT NOT NULL`
- `line_no INTEGER NOT NULL`
- `record_hash TEXT` (optional but strongly recommended; drift verification)
- `subsystem_record_kind TEXT` (optional normalized hint from adapter)
- PRIMARY KEY `(tape_uid, record_ord)`

Notes:
- no full JSON payload duplication in Phase 1 of generic catalog
- if needed later: optional `record_json TEXT` for debug-only mode

### `tape_index_state`

Purpose:
- generic incremental refresh checkpoint per tape

Suggested columns:
- `tape_uid TEXT PRIMARY KEY`
- `subsystem_id TEXT NOT NULL`
- `last_indexed_record_ord INTEGER NOT NULL`
- `last_file_path TEXT`
- `last_line_no INTEGER`
- `last_record_hash TEXT`
- `last_refresh_at TEXT NOT NULL`
- `refresh_mode TEXT NOT NULL` (`rebuild` / `incremental`)
- `drift_status TEXT` (`ok`, `rebuild_fallback`, ...)

This replaces “session is the refresh primitive” at the core layer.

---

## Scope Subsystem Migration (A1 projection)

Current scope tables are valid and useful:
- `sessions`, `session_labels`, `session_index_state`
- `commits`, `scopes`, `scope_labels`, `scope_vars`, `scope_meta_kv`

Migration strategy:
- keep these tables and current `v_scope_*` views stable
- re-implement their indexing through a **scope adapter** under the new generic refresh/catalog framework

Important:
- `session_index_state` can remain as a scope-specific summary/checkpoint table
- but generic refresh correctness should be anchored in `tape_index_state`

Scope adapter responsibilities:
- discover scope tapes
- parse commit records
- index typed scope metadata tables
- optionally populate generic `tape_records` rows with normalized `record_type`, `writer`, `timetag`

---

## Blobstorage Subsystem Integration (next real test)

Blobstorage already emits tapes (metadata stream).

Add a blobstorage adapter that:
- discovers blob metadata tapes
- indexes generic tape catalog rows (`tapes`, `tape_records`, `tape_index_state`)
- builds typed blob metadata tables/views (A1)

Candidate blob views (examples):
- `v_blob_events`
- `v_blob_inventory`
- `v_blob_latest_meta`

Minimum requirement:
- users can query blob metadata/provenance with SQL via `@simos sqlite.execute(...)`
- no special-case scope assumption in refresh/core catalog

---

## Public SQL Surface Strategy

### 1. Generic views (cross-subsystem)

Proposed:
- `v_tapes`
- `v_tape_records`
- `v_tape_index_state`

Use cases:
- discover what subsystems/tapes exist
- inspect refresh state and drift fallback history
- correlate file/line provenance generically

### 2. Subsystem views (namespaced)

Already established pattern (keep):
- `v_scope_*`

Future:
- `v_blob_*`

Contract:
- row grain is explicit in view name/docs
- common provenance column names reused where possible:
  - `subsystem_id`, `tape_uid`, `session_id` (if applicable), `src_file`, `src_line`, `tape_record_ord`, `tape_file`, `tape_line_no`

### 3. Raw normalized tables are internal

Guideline for docs/examples:
- document views as public API
- avoid telling users to query internal tables unless debugging internals

---

## Refresh / Drift Strategy (generalized)

### Core rule

Refresh is performed per tape using `tape_index_state`.

For each discovered tape:
- if unseen -> full index for that tape
- if seen -> attempt incremental append indexing
- verify indexed prefix (or terminal checkpoint) for drift detection
- on drift -> rebuild fallback (tape-level or full DB depending policy)

### Fallback policy (initial)

Prefer simple correctness first:
- any detected drift in any indexed tape => full DB rebuild fallback

Later optimization:
- subsystem-local rebuild fallback
- tape-local reindex if isolated and safe

### Determinism requirements

- stable tape discovery ordering
- stable tape IDs (`tape_uid`) derived from canonical project-relative paths + subsystem
- stable record ordering (`record_ord`)
- stable subsystem adapter ordering for schema/view creation

---

## Implementation Plan (phased)

### Phase 4A — Generic tape catalog scaffold (scope-only population first)

Goal:
- introduce generic backbone without breaking current scope SQL users

Tasks:
- add generic tables: `subsystems`, `tapes`, `tape_records`, `tape_index_state`
- add generic views: `v_tapes`, `v_tape_records`, `v_tape_index_state`
- populate these tables from the **scope subsystem only** (adapter style)
- keep existing scope tables/views unchanged

Acceptance:
- current `v_scope_*` queries still pass unchanged
- new generic views list scope tapes and commit-record rows

### Phase 4B — Refactor scope indexing into a registered adapter

Goal:
- make scope subsystem a plugin/adapter rather than hardcoded core path

Tasks:
- extract scope-specific indexing into `SQLiteIndex/Adapters/ScopeAdapter` (or equivalent)
- registry-driven schema contribution + indexing + views
- move scope refresh-specific state updates behind adapter hook

Acceptance:
- no behavior regression in current scope tests
- refresh path still supports drift fallback

### Phase 4C — Blobstorage adapter + first `v_blob_*` views

Goal:
- validate architecture with a second real subsystem

Tasks:
- implement blob tape discovery + generic record catalog indexing
- add typed blob metadata tables and `v_blob_*` views
- add tests covering SQL queries over blob tapes

Acceptance:
- users can query blob metadata via `@simos sqlite.execute(...)`
- no scope-special assumptions remain in core refresh orchestration

### Phase 4D — Kernel reader surface cleanup (explicit subsystem APIs)

Goal:
- make subsystem boundaries obvious in kernel read interfaces

Tasks:
- formalize generic tape discovery functions in `Kernel`
- formalize `Kernel.ScopeTapes.*`
- add `Kernel.BlobTapes.*`
- adjust internal callers to use subsystem modules rather than ad-hoc tape parsing paths

Acceptance:
- internal code paths map clearly to generic vs subsystem-specific surfaces

---

## File/Module Refactor Targets (expected)

Likely impacted files:
- `src/SQLiteIndex/SQLiteIndex.jl` (core orchestration split)
- new adapter modules under e.g. `src/SQLiteIndex/Adapters/`
- `src/Kernel/tapeio/*` (generic tape discovery helpers)
- scope-related kernel readers/parsers (to clarify subsystem boundary)
- blobstorage metadata reader surfaces (new typed module)

Non-goal for first migration slice:
- changing user-facing `v_scope_*` view names/columns

---

## Testing Plan

### Unit/integration tests (SQLiteIndex)

1. Generic catalog population (scope-only)
- `v_tapes` lists scope tapes
- `v_tape_records` contains commit rows with file/line provenance
- deterministic `tape_uid` / `record_ord`

2. Refresh behavior
- no-op refresh updates checkpoints
- append refresh indexes only new records
- drift/truncation triggers rebuild fallback

3. Scope compatibility
- existing `v_scope_*` tests remain green
- no schema regressions in documented view columns

4. Blob adapter (Phase 4C)
- generic views include blob tapes
- `v_blob_*` views return expected metadata

### Macro/query integration tests

With `@simos sqlite.*`:
- open + execute generic views
- open + execute scope views
- open + execute blob views (after blob adapter lands)

---

## Risks / Failure Modes

1. Over-coupling generic catalog to one subsystem
- Mitigation: enforce `subsystem_id` in all generic tables; no session-specific assumptions in core refresh

2. Duplicate provenance logic between generic and subsystem tables
- Mitigation: define canonical provenance column naming and sourcing rules early

3. Excessive schema complexity before second subsystem lands
- Mitigation: implement Phase 4A minimally (scope-only population) but with adapter shape

4. Breaking current SQL users of `v_scope_*`
- Mitigation: freeze current `v_scope_*` views as public contract during migration

---

## Immediate Next Step (recommended)

Implement **Phase 4A**:
- add generic tape catalog tables + `v_tape_*` views
- populate them from current scope tapes only
- keep current scope tables/views unchanged

This gives the architecture spine first, without delaying current scope workflows.

