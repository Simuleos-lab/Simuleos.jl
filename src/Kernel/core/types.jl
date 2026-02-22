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
# Scope Variables
# --------------------------------------------------

"""Abstract base for all scope variable wrappers."""
abstract type ScopeVariable end

"""
    InlineScopeVariable

A variable whose value is stored inline in the tape JSON.
"""
struct InlineScopeVariable <: ScopeVariable
    level::Symbol           # :local or :global
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

# --------------------------------------------------
# Scope & Commits
# --------------------------------------------------

"""
    SimuleosScope

A snapshot of variables captured at a specific point in execution.
Contains labels for identification, variable bindings, and metadata.
"""
mutable struct SimuleosScope
    labels::Vector{String}
    variables::Dict{Symbol, ScopeVariable}
    metadata::Dict{Symbol, Any}
end

# Default constructor
SimuleosScope() = SimuleosScope(String[], Dict{Symbol, ScopeVariable}(), Dict{Symbol, Any}())

"""
    ScopeStage

Accumulator for scopes between commits.
Captures are collected here until flushed by a commit.
"""
mutable struct ScopeStage
    captures::Vector{SimuleosScope}
    inline_vars::Set{Symbol}     # Variables marked for inline JSON
    blob_vars::Set{Symbol}       # Variables marked for blob storage
    meta_buffer::Dict{Symbol, Any}  # Metadata to attach to next capture
end

ScopeStage() = ScopeStage(SimuleosScope[], Set{Symbol}(), Set{Symbol}(), Dict{Symbol, Any}())

"""
    ScopeCommit

A committed group of scopes written to the tape.
"""
struct ScopeCommit
    commit_label::String
    metadata::Dict{String, Any}
    scopes::Vector{SimuleosScope}
end

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
    SimuleosProject

Represents a project with a `.simuleos/` directory.
"""
mutable struct SimuleosProject
    id::Union{Nothing, String}
    root_path::String
    simuleos_dir::String
    blobstorage::BlobStorage
    git_handler::Any        # GitHandler or nothing
end

"""
    GitHandler

Repository driver used by Kernel git metadata functions.
"""
struct GitHandler
    root_path::String
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
# WorkSession
# --------------------------------------------------

"""
    WorkSession

An active recording session. Manages staged scopes, simignore rules,
and session metadata.
"""
mutable struct WorkSession
    session_id::Base.UUID
    labels::Vector{String}
    stage::ScopeStage
    metadata::Dict{String, Any}
    simignore_rules::Vector{Dict{Symbol, Any}}
    _settings_cache::Dict{String, Any}
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
    bootstrap::Dict{String, Any}
    project::Union{Nothing, SimuleosProject}
    home::Union{Nothing, SimuleosHome}
    worksession::Union{Nothing, WorkSession}
    settings::Dict{String, Any}  # Merged settings (replaces UXLayers)
end

# --------------------------------------------------
# Global singleton
# --------------------------------------------------

"""Global SimOs instance. `nothing` when uninitialized."""
const SIMOS = Ref{Union{Nothing, SimOs}}(nothing)
