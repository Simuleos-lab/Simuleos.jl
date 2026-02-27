# Simuleos Object Ontology (Current)

Source basis: current `src/` object definitions (`struct`, `mutable struct`, key singleton refs), grouped by subsystem.

## Taxonomy roots

- `ScopeVariable` - Abstract base type for how a captured variable is represented inside a scope (inline/blob/hash/void). (`src/Kernel/core/types.jl:50`)
- `PartialCapture` - Abstract base type for independent provenance/context slices used by the context-capture subsystem. (`src/Kernel/core/capture_types.jl:10`)

## Context capture objects

- `SettingsCapture` - Captures the settings keys/values accessed during a capture window for provenance. (`src/Kernel/core/capture_types.jl:17`)
- `SourceCapture` - Stores source-control metadata (commit/branch/dirty/describe) captured for a session. (`src/Kernel/core/capture_types.jl:27`)
- `EnvironmentCapture` - Stores runtime environment facts (Julia/host/OS/threads/time) for provenance. (`src/Kernel/core/capture_types.jl:39`)
- `ExecutionCapture` - Stores execution-site metadata (file/line/thread/time) for a capture event. (`src/Kernel/core/capture_types.jl:53`)

## Blob and record references

- `BlobRef` - Content-addressed reference to a serialized blob payload. (`src/Kernel/core/types.jl:15`)
- `BlobStorage` - Driver object pointing at the `.simuleos/blobs/` storage root. (`src/Kernel/core/types.jl:24`)
- `RecordRef` - Content-addressed reference to a generic tape record with full hash plus short display/tag form. (`src/Kernel/core/types.jl:38`)
- `TapeIO` - Handle for reading/writing a tape stored as a JSONL file or fragmented tape directory. (`src/Kernel/core/types.jl:155`)

## Scope variable wrappers

- `InlineScopeVariable` - Represents a captured variable whose value is stored directly in tape JSON. (`src/Kernel/core/types.jl:57`)
- `BlobScopeVariable` - Represents a captured variable stored out-of-line in blob storage and referenced by `BlobRef`. (`src/Kernel/core/types.jl:68`)
- `VoidScopeVariable` - Represents a variable intentionally not captured as a value (for unsupported/non-serializable types). (`src/Kernel/core/types.jl:79`)
- `HashedScopeVariable` - Represents a variable by value fingerprint only, enabling change detection without value recovery. (`src/Kernel/core/types.jl:90`)

## Scope trace core

- `SimuleosScope` - A single recorded snapshot of selected variables plus labels and metadata at one execution point. (`src/Kernel/core/types.jl:106`)
- `ScopeStage` - In-memory accumulator of captured scopes and capture-mode directives before they are committed. (`src/Kernel/core/types.jl:121`)
- `ScopeCommit` - A logical commit record grouping one or more `SimuleosScope` snapshots for tape persistence. (`src/Kernel/core/types.jl:136`)

## Project and runtime environment

- `SimuleosProject` - Project driver for one repository/root with its `.simuleos` directory, blob storage, and optional git handler. (`src/Kernel/core/types.jl:168`)
- `GitHandler` - Minimal repository driver object used by Kernel git metadata functions. (`src/Kernel/core/types.jl:181`)
- `SimuleosHome` - Driver for the global Simuleos home directory (`~/.simuleos`). (`src/Kernel/core/types.jl:194`)
- `SimuleosSandbox` - Runtime metadata describing a sandbox-managed home/project pair created by `sim_init!`. (`src/Kernel/core/types.jl:207`)
- `WorkSession` - Active recording session state managing staged captures, queued commits, filters, cache context hashes, and capture-related runtime state. (`src/Kernel/core/types.jl:225`)
- `SimOs` - Root engine state object holding project/home/session/settings and shared runtime caches. (`src/Kernel/core/types.jl:303`)

## Settings system

- `SettingsLayer` - One named settings source/layer with normalized key-value data and source metadata. (`src/Kernel/core/types.jl:256`)
- `SettingsRegistryEntry` - Registry rule for one canonical setting key including aliases and optional source-priority policy. (`src/Kernel/core/types.jl:271`)
- `SettingsStack` - Ordered settings layers plus lazy effective-resolution caches and registry indexes (settings SSOT). (`src/Kernel/core/types.jl:282`)

## Tape iteration and read infrastructure

- `CommitIterator` - Typed iterator wrapper that converts filtered raw tape records into `ScopeCommit` objects. (`src/Kernel/scopetapes/read.jl:10`)
- `TapeRecordFilterCtx` - Mutable callback context carrying current tape file/line and stop flag during filtered tape scans. (`src/Kernel/tapeio/tape.jl:245`)
- `FilteredTapeRecordIterator` - Lazy iterator over parsed tape records with line-level and JSON-level filtering hooks. (`src/Kernel/tapeio/tape.jl:271`)
- `_FilteredTapeRecordState` - Internal mutable iteration state for `FilteredTapeRecordIterator` across files/lines/IO handles. (`src/Kernel/tapeio/tape.jl:285`)

## Errors and integrity guards

- `BlobAlreadyExistsError` - Exception raised when writing an existing blob without `overwrite=true`. (`src/Kernel/blobstorage/blob.jl:14`)
- `_SQLiteIndexDriftError` - Internal exception used when the SQLite metadata index diverges from tape contents. (`src/SQLiteIndex/SQLiteIndex.jl:145`)

## Global singleton state objects

- `SIMOS` - Global singleton `Ref` that holds the current `SimOs` instance (or `nothing` when uninitialized). (`src/Kernel/core/types.jl:320`)
- `SIMOS_GLOBAL_LOCK` - Process-wide lock that serializes `@simos` operations when enabled. (`src/SimosAPI/macro.jl:20`)
- `SIMOS_GLOBAL_LOCK_ENABLED` - Runtime flag (`Ref`) controlling whether `@simos` acquires the global lock. (`src/SimosAPI/macro.jl:29`)
