# Core type definitions for Simuleos
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
    home_path::String = Core.default_home_path()  # ~/.simuleos
    project_root::Union{Nothing, String} = nothing  # auto-detect or explicit
    bootstrap::Dict{String, Any} = Dict{String, Any}()  # bootstrap settings

    # Lazy subsystem references (initialized on first access)
    _project::Any = nothing  # Will be Project once loaded
    _home::Any = nothing     # Will be SimuleosHome once loaded

    # UXLayers integration (built at sim_activate() time)
    ux::Any = nothing  # Will be UXLayerView once loaded

    # Subsystem references
    recorder::Any = nothing  # Will be SessionRecorder when recording
    reader::Any = nothing    # Will be SessionReader when reading
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
# Context I/O Types (Session, Scope, etc.)
# ==================================

"""
    ScopeVariable

A captured variable within a scope.
"""
@kwdef struct ScopeVariable
    name::String
    src_type::String                          # string repr for JSON, truncated to 25 chars
    value::Union{Nothing, Any} = nothing      # only if lite
    blob_ref::Union{Nothing, String} = nothing # SHA1 hash if stored
    src::Symbol = :local                      # :local or :global
end

"""
    Scope

A snapshot of variables at a point in time.
"""
@kwdef mutable struct Scope
    label::String = ""
    timestamp::Dates.DateTime = Dates.now()
    isopen::Bool = true                       # lifecycle tracking
    variables::Dict{String, ScopeVariable} = Dict{String, ScopeVariable}()
    labels::Vector{String} = String[]         # context labels from @session_context
    data::Dict{Symbol, Any} = Dict{Symbol, Any}()  # context data from @session_context
    blob_set::Set{Symbol} = Set{Symbol}()     # per-scope blob requests
end

"""
    Stage

Collection of scopes pending commit.
"""
@kwdef mutable struct Stage
    scopes::Vector{Scope} = Scope[]
    current_scope::Scope = Scope()            # explicit open scope
end

"""
    SessionRecorder

A recording session with metadata and staged scopes.
References `SIMOS[].project` for project-level data instead of storing root_dir.
"""
@kwdef mutable struct SessionRecorder
    label::String
    stage::Stage
    meta::Dict{String, Any}    # git, julia version, etc.
    simignore_rules::Vector{Dict{Symbol, Any}} = Dict{Symbol, Any}[]

    # Settings cache (reset at @session_init start, populated lazily)
    # Uses :__MISSING__ sentinel for UXLayers misses to avoid repeated calls
    _settings_cache::Dict{String, Any} = Dict{String, Any}()
end

"""
    SessionReader

Manages reading state on `sim.reader`. Minimal for now — delegates to handlers in Core.
"""
@kwdef mutable struct SessionReader
    session_label::Union{Nothing, String} = nothing
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
