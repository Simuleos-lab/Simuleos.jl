# SQLite SSOT: Reading Boundary and Query Contract

Date: 2026-02-27

## Scope of this note

This note consolidates the recent design discussion about:

- reducing non-SQLite read/query semantics to a minimum,
- making SQLite the SSOT query layer,
- clarifying `each_scopes(proj; ...)` status and scope meaning,
- defining what query return objects should look like,
- deciding whether to add parsing/type-sink behavior in SQLite calls.

## Current direction (stated goals)

- SQLite index is the SSOT query layer.
- Core tape iteration should be minimal and record-agnostic.
- Tape/kernel readers should treat a record as just a record.
- Subsystem semantics (commit/scope/blob/context meaning) should live in SQLite index builder and SQLite-facing query layer.

## Clarification: `each_scopes(proj; ...)`

- `each_scopes` is currently still part of the public export surface and active interface (`src/Simuleos.jl`), not deprecated in code.
- It is the explicit project-driven read interface (older style), while `@simos` is the runtime/control/write interface.
- Today it returns `SimuleosScope` values parsed from commit-shaped tape records.

## Clarification: what a scope is now

- A scope is still a variable snapshot object (`SimuleosScope`) with:
  - `labels`
  - `variables::Dict{Symbol, ScopeVariable}`
  - `metadata`
- Captured variables are wrappers (`InlineScopeVariable`, `BlobScopeVariable`, `HashedScopeVariable`, `VoidScopeVariable`).
- New context capture records (`RecordRef`/`generic_record`) are separate provenance objects and not the same thing as scopes.

## Non-SQLite reading mechanisms (inventory)

### A) Non-SQLite readers with embedded subsystem semantics

- Scope/commit parsing from tape dicts:
  - `_parse_scope_variable`, `_parse_scope`, `_parse_commit` (`src/Kernel/scopetapes/base.jl`)
- Materialized commit reader:
  - `iterate_commits` (`src/Kernel/scopetapes/base.jl`)
- Scope query/read API:
  - `each_commits`, `each_scopes`, `latest_scope`, `scope_table` (`src/ScopeReader/ScopeReader.jl`)
- Scope-specific filters/value expansion:
  - `_src_file_match`, `_scope_label_match`, `_scope_expand_runtime!`, `value(...)` (`src/ScopeReader/ScopeReader.jl`)
- Blob metadata-from-tape readers:
  - `_blob_tape_indexed_hashes`, `blob_metadata`, `blob_metadata_indexed` (`src/Kernel/blobstorage/blob.jl`)
- Blob payload reader:
  - `blob_read` (`src/Kernel/blobstorage/blob.jl`)
- Generic-record resolver:
  - `record_resolve` (`src/Kernel/tapeio/record.jl`)
- Context resolver:
  - `context_resolve` (`src/WorkSession/context.jl`)
- Session label/id resolution by scanning `session.json`:
  - `find_session_id`, `resolve_session_id` (`src/Kernel/core/project.jl`)
- Macro entrypoints that call non-SQLite readers:
  - `@simos blob.meta`, `@simos context.resolve` (`src/SimosAPI/macro/handlers.jl`, `src/SimosAPI/macro/runtime.jl`)

### B) Non-SQLite readers that are tape-agnostic (record-agnostic)

- Raw tape iteration:
  - `Base.iterate(TapeIO)`, `iterate_tape`, `Base.collect(TapeIO)` (`src/Kernel/tapeio/tape.jl`)
- Generic filtered scan primitives:
  - `scan_tape_records_filtered`, `each_tape_records_filtered`, `TapeRecordFilterCtx`, `stop!` (`src/Kernel/tapeio/tape.jl`)
- Generic helpers:
  - `findfirst_tape_record`, `findlast_tape_record`, `any_tape_record` (`src/Kernel/tapeio/tape.jl`)

## SQLite query interface today

- `@simos sqlite.execute(...)` currently returns raw `SQLite.DBInterface.execute(...)` iterable rows.
- Consumers currently materialize manually (for example with `SQLite.values(row)` in tests).
- SQLiteIndex internals already have helper materialization into `Dict{Symbol,Any}` (`_sqlite_materialize_row`, `_sqlite_all_dicts`) but this is internal and not public.

## Design discussion: parsing capabilities on query results

### Evaluated options

- Overload `sqlite.execute` with parsing/typed sinks.
- Keep `sqlite.execute` raw and add a separate decoded API (`sqlite.fetch` or `sqlite.query`) with optional sink/decoder.
- Add subsystem-specific query helpers over SQLite views.
- Add subsystem-scoped macro commands while keeping SQL as the query language, for example `@simos sqlite.<subsystem>.fetch(...)`.

### Recommended shape discussed

- Keep `execute` as raw escape hatch.
- Add decoded query API separately (materialized rows + optional parsing).
- Put subsystem semantics only in SQLite/adapters/query layer, not tape/core readers.
- Prefer subsystem-scoped fetch callers over a single generic decoded caller.
- Use `sqlite` namespace in the command path (not `tape`) because reads are from SQLite index views.

### Decision update (latest)

- Adopt subsystem-scoped fetch interface:
  - `@simos sqlite.<subsystem>.fetch(...)`
- Keep SQL as the query language for these calls.
- Keep general raw path available:
  - `@simos sqlite.execute(...)`
- Allow many subsystem fetch callers as needed (blob/scope/context/etc.), each with subsystem-local parsing rules.
- Keep basic querying helpers for subsystem-internal use only.
- Do not keep iterator-style/fancy querying surfaces as first-class API.

## Return object contract discussion

### Proposed/considered

- Explicit stable decoded-value contract for query API.
- Optional typed mapping or sink in a higher-level query call (not on `execute`).

### Final user preference (important)

- Do not load/convert to blob refs automatically.
- Keep outputs in the same lite/primitive system.
- User/operator can interpret whether a row/value corresponds to blob-backed data based on row fields.

## Decision snapshot from this discussion

- Keep tape/kernel read core generic and minimal.
- Move/centralize subsystem read semantics toward SQLite.
- Preserve `sqlite.execute` as raw.
- Add parsed/materialized read entrypoints as subsystem-scoped calls:
  - `@simos sqlite.<subsystem>.fetch(...)`
- Keep parsing API separate from `execute`.
- Do not force BlobRef conversion in decoded query path; preserve lite primitives.
- Keep non-SQLite basic querying only for subsystem internals.
- Prefer materialized/basic query results over iterator-style user-facing reads.

## Implications for refactor planning

- Candidate removals/de-emphasis:
  - scope/commit semantic readers outside SQLite for user-facing query flows.
  - direct blob metadata tape scans as public query mechanism.
- Candidate additions:
  - SQLite-first query helpers and documented row contracts.
  - explicit distinction between raw SQL execution and optional materialized fetch APIs.
- Compatibility stance:
  - user preference indicates semantics should be discoverable via row fields, not hidden type inflation.

## Open implementation questions (to resolve in next step)

- First subsystem list to support on day-1 (`blobs`, `scope`, `context`, ...).
- Exact call signature of subsystem fetch:
  - positional forms (`sql`, `params`) and optional keyword materialization options.
- Exact lite row contract for subsystem views (required fields, nullability, numeric/string normalization).
- Whether to add companion single-row helpers later (`one`/`first`) per subsystem.
