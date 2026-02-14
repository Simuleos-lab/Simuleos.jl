# Kernel type definitions for Simuleos
# All types are defined here - app modules have access to all types

# ==================================
# Blob Storage
# ==================================

"""
    BlobStorage

Driver object for project-local blob storage under `{project_root}/.simuleos/blobs`.
Holds only the `.simuleos` root directory.
"""
struct BlobStorage
    root_dir::String
end

"""
    BlobRef

Content-addressed reference to a blob file under blobs/<sha1>.jls.
"""
struct BlobRef
    hash::String
end

# ==================================
# Scoperias Types
# ==================================

"""
    ScopeVariable

A captured variable payload.
"""
abstract type ScopeVariable end

"""
    InMemoryScopeVariable

Scope variable with inline value.
"""
struct InMemoryScopeVariable <: ScopeVariable
    src::Symbol
    type_short::String
    value::Any
end

"""
    BlobScopeVariable

Scope variable stored in blob storage.
"""
struct BlobScopeVariable <: ScopeVariable
    src::Symbol
    type_short::String
    blob_ref::BlobRef
end

"""
    VoidScopeVariable

Scope variable with no stored value (type metadata only).
"""
struct VoidScopeVariable <: ScopeVariable
    src::Symbol
    type_short::String
end

"""
    Scope

Runtime container of named variables, labels, and per-scope context data.
"""
mutable struct Scope
    labels::Vector{String}
    variables::Dict{Symbol, ScopeVariable}
    data::Dict{Symbol, Any}
end

# ==================================
# ScopeTapes Commit Type
# ==================================

"""
    ScopeCommit

Typed commit record for scope tape payloads.
"""
struct ScopeCommit
    commit_label::String
    metadata::Dict{String, Any}
    scopes::Vector{Scope}
end

# ==================================
# TapeIO Types
# ==================================

"""
    TapeIO

Path-based handle to a JSONL tape file.
"""
struct TapeIO
    path::String
end

# ==================================
# SimOs - The App Object
# ==================================

"""
    SimOs

The central state object for Simuleos. Holds bootstrap data and active subsystem
references. Access via `Simuleos.SIMOS[]`.
"""
@kwdef mutable struct SimOs
    # Bootstrap data (provided at creation)
    home_path::String = default_home_path()  # ~/.simuleos
    project_root::Union{Nothing, String} = nothing  # auto-detect or explicit
    bootstrap::Dict{String, Any} = Dict{String, Any}()  # bootstrap settings

    # Active project reference (set at sim_init/sim_activate)
    project::Any = nothing  # Will be Project once activated

    # Home driver cache
    _home::Any = nothing     # Will be SimuleosHome once loaded

    # UXLayers integration (built at sim_activate() time)
    ux::Any = nothing  # Will be UXLayerView once loaded

    # Subsystem references
    worksession::Any = nothing  # Will be WorkSession while an app session is active
end

# ==================================
# Project - Entry point object
# ==================================

"""
    Project

Represents a Simuleos project (a directory with .simuleos/).
Contains sessions and provides access to project-level operations.
"""
@kwdef mutable struct Project
    id::String                           # Project UUID (from project.json)
    root_path::String                    # Project root directory
    simuleos_dir::String                 # .simuleos/ path
    blobstorage::BlobStorage             # project blob storage driver
    git_handler::Any = nothing           # GitHandler if git repo
end

# ==================================
# Context I/O Types (ScopeStage, etc.)
# ==================================

"""
    ScopeStage

Recording-only stage with finalized captures and one open current scope.
"""
@kwdef mutable struct ScopeStage
    captures::Vector{Scope} = Scope[]
    current_scope::Scope = Scope()
    blob_refs::Dict{Symbol, BlobRef} = Dict{Symbol, BlobRef}()
end

"""
    WorkSession

A work session with metadata and staged scopes.
References `SIMOS[].project` for project-level data instead of storing root_dir.
"""
@kwdef mutable struct WorkSession
    label::String
    stage::ScopeStage
    meta::Dict{String, Any}    # git, julia version, etc.
    simignore_rules::Vector{Dict{Symbol, Any}} = Dict{Symbol, Any}[]

    # Settings cache (reset at @session_init start, populated lazily)
    # Uses :__MISSING__ sentinel for UXLayers misses to avoid repeated calls
    _settings_cache::Dict{String, Any} = Dict{String, Any}()
end

# ==================================
# Git Types
# ==================================

"""
    GitHandler

A struct representing a git repository for safe git operations.
"""
struct GitHandler
    path::String
    gitdir::Union{String, Nothing}
end

# ==================================
# Registry Types (stubs)
# ==================================

"""
    SimuleosHome

Represents the ~/.simuleos home directory with registry and config.
"""
@kwdef mutable struct SimuleosHome
    path::String
    # Future: registry, config, etc.
end

# ==================================
# Traceability Types (stubs)
# ==================================

"""
    ContextLink

Links an output artifact (hash/path) to its generation context.
"""
@kwdef struct ContextLink
    artifact_hash::String
    artifact_path::Union{Nothing, String} = nothing
    session_label::String
    commit_label::String
    timestamp::Dates.DateTime
end
