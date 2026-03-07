# ============================================================
# types.jl — All type definitions for Simuleos
# ============================================================

# --------------------------------------------------
# Blob Storage
# --------------------------------------------------

"""
    BlobRef(hash::String)

Content-addressed reference to a serialized blob.
The hash is the hex SHA-1 of the serialization key.
"""
struct BlobRef
    hash::String
end

"""
    BlobStorage

Driver for content-addressed blob storage under `.simuleos/blobs/`.
"""
struct BlobStorage
    blobs_dir::String
end

# --------------------------------------------------
# RecordRef — Content-addressed record reference
# --------------------------------------------------

"""
    RecordRef

Content-addressed reference to a generic tape record.
`hash` is the full hex SHA-1; `short` is a prefix for display/filenames.
"""
struct RecordRef
    hash::String
    short::String
end

Base.string(ref::RecordRef) = ref.short

# --------------------------------------------------
# Scope Variables
# --------------------------------------------------

"""Abstract base for all scope variable wrappers."""
abstract type ScopeVariable end

"""
    InlineScopeVariable

A variable whose value is stored inline in the tape JSON.
"""
struct InlineScopeVariable <: ScopeVariable
    level::Symbol           # :local, :global, or :shared
    type_short::String      # Type name (truncated to 50 chars)
    value::Any
end

"""
    BlobScopeVariable

A variable whose value is stored as a blob, referenced by hash.
"""
struct BlobScopeVariable <: ScopeVariable
    level::Symbol
    type_short::String
    blob_ref::BlobRef
end

"""
    VoidScopeVariable

A variable whose value was not captured (e.g. Module, Function).
"""
struct VoidScopeVariable <: ScopeVariable
    level::Symbol
    type_short::String
end

"""
    HashedScopeVariable

A variable whose value is stored as a SHA-1 fingerprint only.
The value is not recoverable, but the hash enables change detection.
"""
struct HashedScopeVariable <: ScopeVariable
    level::Symbol
    type_short::String
    value_hash::String   # SHA-1 hex of serialized value
end

# --------------------------------------------------
# Namespace/Scope DataClasses
# --------------------------------------------------

function _dataclass_scope_variables(
        variables::AbstractDict,
        default_level::Symbol,
    )::Dict{Symbol, ScopeVariable}
    out = Dict{Symbol, ScopeVariable}()
    for (name, val) in variables
        key = _to_symbol_key(name)
        if val isa ScopeVariable
            out[key] = val
        else
            out[key] = InlineScopeVariable(default_level, type_short(val), val)
        end
    end
    return out
end

function _dataclass_symbol_any(data::AbstractDict)::Dict{Symbol, Any}
    out = Dict{Symbol, Any}()
    for (k, v) in pairs(data)
        out[_to_symbol_key(k)] = v
    end
    return out
end

struct SrcNamespaceBindingsV1 <: SimuleosDataClass
    labels::Vector{String}
    variables::Dict{Symbol, ScopeVariable}
    metadata::Dict{Symbol, Any}
end

function SrcNamespaceBindingsV1(
        labels::AbstractVector,
        variables::AbstractDict,
        metadata::AbstractDict,
    )
    return SrcNamespaceBindingsV1(
        _dataclass_string_vec(labels),
        _dataclass_scope_variables(variables, :local),
        _dataclass_symbol_any(metadata),
    )
end

SrcNamespaceBindingsV1() = SrcNamespaceBindingsV1(
    String[],
    Dict{Symbol, ScopeVariable}(),
    Dict{Symbol, Any}(),
)

struct SnapScopeV1 <: SimuleosDataClass
    labels::Vector{String}
    variables::Dict{Symbol, ScopeVariable}
    metadata::Dict{Symbol, Any}
end

function SnapScopeV1(
        labels::AbstractVector,
        variables::AbstractDict,
        metadata::AbstractDict,
    )
    return SnapScopeV1(
        _dataclass_string_vec(labels),
        _dataclass_scope_variables(variables, :local),
        _dataclass_symbol_any(metadata),
    )
end

SnapScopeV1() = SnapScopeV1(String[], Dict{Symbol, ScopeVariable}(), Dict{Symbol, Any}())

struct SnapSharedV1 <: SimuleosDataClass
    labels::Vector{String}
    variables::Dict{Symbol, ScopeVariable}
    metadata::Dict{Symbol, Any}
    shared_key::String
end

function SnapSharedV1(
        labels::AbstractVector,
        variables::AbstractDict,
        metadata::AbstractDict,
        shared_key::AbstractString,
    )
    return SnapSharedV1(
        _dataclass_string_vec(labels),
        _dataclass_scope_variables(variables, :shared),
        _dataclass_symbol_any(metadata),
        String(shared_key),
    )
end

SnapSharedV1(shared_key::AbstractString) = SnapSharedV1(
    String[String(shared_key)],
    Dict{Symbol, ScopeVariable}(),
    Dict{Symbol, Any}(),
    String(shared_key),
)

SnapSharedV1() = SnapSharedV1(
    String[],
    Dict{Symbol, ScopeVariable}(),
    Dict{Symbol, Any}(),
    "",
)

# --------------------------------------------------
# CaptureTree & CapturePolicy
# --------------------------------------------------

"""
    CaptureTree

A recursive, labeled container for captured snapshots.
"""
mutable struct CaptureTree
    label::String
    snapshots::Vector{SimuleosDataClass}
    children::Vector{CaptureTree}
    metadata::Dict{String, Any}
end

CaptureTree(label::String="") = CaptureTree(label, SimuleosDataClass[], CaptureTree[], Dict{String, Any}())

"""
    RecCaptureCommitV1 <: SimuleosDataClass

Runtime representation of a `rec.capture_commit` record.

Wraps a `CaptureTree` (the captured content) with record-level metadata
(label, commit metadata). The `capture` field's `CaptureTree` should be
treated as immutable once inside a committed record.
"""
struct RecCaptureCommitV1 <: SimuleosDataClass
    label::String
    capture::CaptureTree
    metadata::Dict{String, Any}
end

function RecCaptureCommitV1(;
        label::AbstractString = "",
        capture::CaptureTree = CaptureTree(),
        metadata::AbstractDict = Dict{String, Any}(),
    )
    return RecCaptureCommitV1(
        String(label),
        capture,
        _dataclass_string_dict(metadata),
    )
end

"""
    CapturePolicy

Capture policy controlling how variables are stored (inline, blob, hash).
Lives on `WorkSession` separately from the `CaptureTree` stage.
"""
mutable struct CapturePolicy
    inline_vars::Set{Symbol}
    blob_vars::Set{Symbol}
    hash_vars::Set{Symbol}
    meta_buffer::Dict{Symbol, Any}
end

CapturePolicy() = CapturePolicy(Set{Symbol}(), Set{Symbol}(), Set{Symbol}(), Dict{Symbol, Any}())

# --------------------------------------------------
# TapeIO
# --------------------------------------------------

"""
    TapeIO(path::String)

Handle for tape storage.
- If `path` is a `.jsonl` file path, records are stored in that file.
- Otherwise `path` is treated as a fragmented tape directory using
  `fragN.jsonl` files.
Supports iteration and append operations in both modes.
"""
struct TapeIO
    path::String
end

# --------------------------------------------------
# Project
# --------------------------------------------------

"""
    GitHandler

Repository driver used by Kernel git metadata functions.
"""
struct GitHandler
    root_path::String
end

"""
    TapeRegistryEntry

Metadata for a registered tape in the project's tape registry.
"""
struct TapeRegistryEntry
    path::String         # absolute path to tape (file or directory)
    source::Symbol       # :session, :blobstorage, :cache, :unknown, etc.
    meta::Dict{String, Any}  # arbitrary metadata (session_id, shard_prefix, etc.)
end

"""
    TapeRegistry

In-memory registry of all known tapes for a project.
Dict keyed by tape path for fast lookup and dedup.
"""
mutable struct TapeRegistry
    entries::Dict{String, TapeRegistryEntry}
end

TapeRegistry() = TapeRegistry(Dict{String, TapeRegistryEntry}())

"""
    SimuleosProject

Represents a project with a `.simuleos/` directory.
"""
mutable struct SimuleosProject
    id::Union{Nothing, String}
    root_path::String
    simuleos_dir::String
    blobstorage::BlobStorage
    git_handler::Union{Nothing, GitHandler}
    tape_registry::TapeRegistry
end

# --------------------------------------------------
# Home
# --------------------------------------------------

"""
    SimuleosHome

The global Simuleos home directory (`~/.simuleos/`).
"""
mutable struct SimuleosHome
    path::String
end

# --------------------------------------------------
# Sandbox
# --------------------------------------------------

"""
    SimuleosSandbox

Runtime metadata for a sandboxed Simuleos home/project pair managed by `sim_init!`.
"""
struct SimuleosSandbox
    root_path::String
    home_path::String
    project_root::String
    cleanup_on_reset::Bool
    origin::Symbol  # :explicit or :ephemeral
end

# --------------------------------------------------
# WorkSession
# --------------------------------------------------

"""
    WorkSession

An active recording session. Manages staged scopes, simignore rules,
queued commits pending tape flush, and session metadata.
"""
mutable struct WorkSession
    # Session identity/lifecycle subsystem
    session_id::Base.UUID
    labels::Vector{String}
    is_finalized::Bool
    metadata::Dict{String, Any}

    # Stage subsystem
    stage::CaptureTree
    pending_commits::Vector{RecCaptureCommitV1}

    # Capture configuration subsystem
    capture_policy::CapturePolicy
    simignore_rules::Vector{Dict{Symbol, Any}}
    capture_filter_defs::Dict{String, Vector{Dict{Symbol, Any}}}
    capture_filter_bindings::Dict{String, Vector{String}}
    # Runtime-only counters for gated `rec.queue(...; cmt_every=...)` calls.
    queue_counters::Dict{String, Int}

    # Context subsystem (runtime-only)
    # Runtime-only registry of named context hashes (not persisted to session.json).
    context_hash_reg::Dict{String, String}

    # Settings observability subsystem (runtime-only)
    settings_access_tracking::Bool
    # Settings access tracking (runtime-only, not persisted).
    settings_access_log::Union{Nothing, Dict{String, Any}}

    # Runtime capture subsystem
    # Capture subsystem: source and environment snapshots (runtime-only).
    source_capture::Union{Nothing, SrcCodebaseV1}
    environment_capture::Union{Nothing, SrcRuntimeHostV1}
end

# --------------------------------------------------
# Settings Stack
# --------------------------------------------------

"""
    SettingsLayer

One named settings layer with normalized key/value data and source metadata.
"""
mutable struct SettingsLayer
    name::Symbol
    kind::Symbol
    is_mutable::Bool
    persistent::Bool
    origin::Dict{String, Any}
    data::Dict{String, Any}
    key_origin::Dict{String, String}   # per-key source tag for observability
end

"""
    SettingsRegistryEntry

Registry rule for a canonical settings key: alias set + optional custom
source-priority resolution policy.
"""
mutable struct SettingsRegistryEntry
    canonical::String
    aliases::Vector{String}
    resolve_priority::Union{Nothing, Vector{Symbol}}
end

"""
    SettingsStack

Ordered layered settings plus lazy cached effective resolution state.
"""
mutable struct SettingsStack
    layers::Vector{SettingsLayer}
    effective::Dict{String, Any}      # memoized resolved winners (may be partial)
    effective_missing::Set{String}    # negative cache for missing keys
    effective_version::Int            # cache epoch; must match `version`
    effective_complete::Bool          # true when `effective` is a full resolved snapshot
    registry::Dict{String, SettingsRegistryEntry}          # canonical -> registry entry
    registry_alias_to_canonical::Dict{String, String}      # alias -> canonical
    version::Int                      # bumps on any layer/source mutation
end

# --------------------------------------------------
# SimOs — Global System State
# --------------------------------------------------

"""
    SimOs

The root state object. Holds references to project, home,
settings, and the active work session.
"""
mutable struct SimOs
    # Runtime lifecycle/config subsystem
    lifecycle::Symbol  # :bootstrap (settings-only pre-init) or :ready (full runtime)
    runtime_settings::Dict{String, Any}

    # Workspace subsystem
    project::Union{Nothing, SimuleosProject}
    home::Union{Nothing, SimuleosHome}
    sandbox::Union{Nothing, SimuleosSandbox}

    # Active state subsystem
    settings_stack::Union{Nothing, SettingsStack}  # Structured layered settings SSOT
    worksession::Union{Nothing, WorkSession}
    shared_scopes::Dict{String, SnapSharedV1}  # In-memory named shared scopes

    # Persistence/cache subsystem
    sqlite_db::Any  # Cached SQLite metadata-index connection (owned by @simos sqlite.*)
    sqlite_db_path::Union{Nothing, String}  # Canonical path for the cached SQLite DB
end

# --------------------------------------------------
# Global singleton
# --------------------------------------------------

"""Global SimOs instance. Usually `:bootstrap` pre-init, `:ready` after `sim_init!()`."""
const SIMOS = Ref{Union{Nothing, SimOs}}(nothing)
