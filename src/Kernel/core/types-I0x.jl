# Kernel type definitions for Simuleos
# All types are defined here - app modules have access to all types

# ==================================
# Blob Storage
# ==================================

"""
    BlobStorage

Driver object for project-local blob storage under `{project_root}/.simuleos/blobs`.
Holds only the project's `.simuleos` directory path.
"""
struct BlobStorage
    simuleos_dir::String
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
    InlineScopeVariable

SimuleosScope variable with inline value.
"""
struct InlineScopeVariable <: ScopeVariable
    level::Symbol
    type_short::String
    value::Any
end

"""
    BlobScopeVariable

SimuleosScope variable stored in blob storage.
"""
struct BlobScopeVariable <: ScopeVariable
    level::Symbol
    type_short::String
    blob_ref::BlobRef
end

"""
    VoidScopeVariable

SimuleosScope variable with no stored value (type metadata only).
"""
struct VoidScopeVariable <: ScopeVariable
    level::Symbol
    type_short::String
end

"""
    SimuleosScope

Runtime container of named variables, labels, and per-scope context data.
"""
mutable struct SimuleosScope
    labels::Vector{String}
    variables::Dict{Symbol, ScopeVariable}
    metadata::Dict{Symbol, Any}
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
    scopes::Vector{SimuleosScope}
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
mutable struct SimOs
    # Activation/bootstrap overrides.
    bootstrap::Dict{String, Any}

    # Active project reference (set at sim_init!)
    project::Any  # Will be SimuleosProject once activated

    # Home driver cache
    home::Any     # Will be SimuleosHome once loaded

    # UXLayers integration (built at sim_init! Phase 0)
    ux::Any  # Will be UXLayerView once loaded

    # Subsystem references
    worksession::Any  # Will be WorkSession while an app session is active
end

# ==================================
# SimuleosProject - Entry point object
# ==================================

"""
    SimuleosProject

Represents a Simuleos project (a directory with .simuleos/).
Contains sessions and provides access to project-level operations.
"""
mutable struct SimuleosProject
    id::Union{Nothing, String}           # Simuleos project UUID (from project.json)
    root_path::String                    # Simuleos project root directory
    simuleos_dir::String                 # .simuleos/ path
    blobstorage::BlobStorage             # project blob storage driver
    git_handler::Any                     # GitHandler if git repo
end

# ==================================
# Context I/O Types (ScopeStage, etc.)
# ==================================

"""
    ScopeStage

Recording-only stage with finalized captures and one open current scope.
"""
mutable struct ScopeStage
    captures::Vector{SimuleosScope}
    current_scope::SimuleosScope
    blob_refs::Dict{Symbol, BlobRef}
end

"""
    WorkSession

A work session with metadata and staged scopes.
References `SIMOS[].project` for project-level data instead of storing `simuleos_dir`.
"""
mutable struct WorkSession
    session_id::Base.UUID
    labels::Vector{String}
    stage::ScopeStage
    metadata::Dict{String, Any}    # git, julia version, etc.
    simignore_rules::Vector{Dict{Symbol, Any}}

    # Settings cache (reset at @session_init start, populated lazily)
    # Uses :__MISSING__ sentinel for UXLayers misses to avoid repeated calls
    _settings_cache::Dict{String, Any}
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
mutable struct SimuleosHome
    path::String
    # Future: registry, config, etc.
end
