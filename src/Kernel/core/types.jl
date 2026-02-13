# Kernel type definitions for Simuleos
# All types are defined here - app modules have access to all types

# ==================================
# File Format Constants
# ==================================

const TAPE_FILENAME = "context.tape.jsonl"
const BLOB_EXT = ".jls"

# ==================================
# SimOs - The App Object
# ==================================

"""
    SimOs

The central state object for Simuleos. Holds bootstrap data and lazy references
to all subsystems. Access via `Simuleos.SIMOS[]`.
"""
@kwdef mutable struct SimOs
    # Bootstrap data (provided at creation)
    home_path::String = default_home_path()  # ~/.simuleos
    project_root::Union{Nothing, String} = nothing  # auto-detect or explicit
    bootstrap::Dict{String, Any} = Dict{String, Any}()  # bootstrap settings

    # Lazy subsystem references (initialized on first access)
    _project::Any = nothing  # Will be Project once loaded
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
    git_handler::Any = nothing           # GitHandler if git repo
end

# ==================================
# Context I/O Types (CaptureContext, Stage, etc.)
# NOTE: ScopeVariable and Scope are now defined in Scoperias (scoperias/types-I0x.jl)
# ==================================

"""
    CaptureContext

Pairs a Scope with work-session metadata (timestamp, capture data, blob requests).
The Scope holds pure runtime data; CaptureContext adds recording concerns.
"""
@kwdef mutable struct CaptureContext
    scope::Scope = Scope()
    timestamp::Dates.DateTime = Dates.now()
    data::Dict{Symbol, Any} = Dict{Symbol, Any}()   # src_file, src_line, threadid
    blob_set::Set{Symbol} = Set{Symbol}()            # per-scope blob requests
end

"""
    Stage

Collection of captures pending commit.
"""
@kwdef mutable struct Stage
    captures::Vector{CaptureContext} = CaptureContext[]
    current::CaptureContext = CaptureContext()
end

"""
    WorkSession

A work session with metadata and staged scopes.
References `SIMOS[].project` for project-level data instead of storing root_dir.
"""
@kwdef mutable struct WorkSession
    label::String
    stage::Stage
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

    function GitHandler(path::String, gitdir::Union{String, Nothing}=nothing)
        new(path, gitdir)
    end
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

# ==================================
# Handler Types (for lazy navigation of .simuleos/ directory structure)
# ==================================

"""
    RootHandler(path::String)

Entry point for querying a .simuleos/ directory.
"""
struct RootHandler
    path::String  # path to .simuleos/
end

"""
    SessionHandler

Points to a session directory under sessions/<label>/.
"""
struct SessionHandler
    root::RootHandler
    label::String
end

"""
    TapeHandler

Points to a context.tape.jsonl file within a session.
"""
struct TapeHandler
    session::SessionHandler
end

"""
    BlobHandler

Points to a blob file under blobs/<sha1>.jls.
"""
struct BlobHandler
    root::RootHandler
    sha1::String
end

# ==================================
# Record Types (typed, loaded from tape/blobs)
# ==================================

"""
    CommitRecord

A typed commit record loaded from the tape. Replaces CommitWrapper.
"""
struct CommitRecord
    session_label::String
    commit_label::String
    metadata::Dict{String, Any}
    scopes::Vector{Any}       # Will hold ScopeRecord objects
    blob_refs::Vector{String}
end

"""
    ScopeRecord

A typed scope record loaded from the tape. Replaces ScopeWrapper.
"""
struct ScopeRecord
    label::String
    timestamp::Dates.DateTime
    variables::Vector{Any}    # Will hold VariableRecord objects
    labels::Vector{String}
    data::Dict{String, Any}
end

"""
    VariableRecord

A typed variable record loaded from the tape. Replaces VariableWrapper.
"""
struct VariableRecord
    name::String
    src_type::String
    value::Any
    blob_ref::Union{Nothing, String}
    src::Symbol
end

"""
    BlobRecord

A typed blob record loaded from disk. Replaces BlobWrapper.
"""
struct BlobRecord
    data::Any
end
