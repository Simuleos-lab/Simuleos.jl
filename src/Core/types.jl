# Core type definitions for Simuleos
# All types are defined here - app modules have access to all types

using Dates

# =============================================================================
# SimOS - The God Object
# =============================================================================

"""
    SimOS

The central state object for Simuleos. Holds bootstrap data and lazy references
to all subsystems. Access via `Simuleos.OS`.
"""
@kwdef mutable struct SimOS
    # Bootstrap data (provided at creation)
    home_path::String = joinpath(homedir(), ".simuleos")
    project_root::Union{Nothing, String} = nothing  # auto-detect or explicit
    bootstrap::Dict{String, Any} = Dict{String, Any}()  # bootstrap settings

    # Lazy subsystem references (initialized on first access)
    # These are Union{Nothing, T} - check and initialize on first access
    _project::Any = nothing  # Will be Project once loaded
    _home::Any = nothing     # Will be SimuleosHome once loaded

    # UXLayers integration (built at activate() time)
    _ux_root::Any = nothing  # Will be UXLayerView once loaded
    _sources::Vector{Dict{String, Any}} = Dict{String, Any}[]  # Settings sources in priority order
end

# =============================================================================
# Project - Entry point object
# =============================================================================

"""
    Project

Represents a Simuleos project (a directory with .simuleos/).
Contains sessions and provides access to project-level operations.
"""
@kwdef mutable struct Project
    root_path::String                    # Project root directory
    simuleos_dir::String                 # .simuleos/ path
    git_handler::Any = nothing           # GitHandler if git repo
end

# =============================================================================
# Context I/O Types (Session, Scope, etc.)
# =============================================================================

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
    timestamp::DateTime = now()
    isopen::Bool = true                       # lifecycle tracking
    variables::Dict{String, ScopeVariable} = Dict{String, ScopeVariable}()
    labels::Vector{String} = String[]         # context labels from @sim_context
    data::Dict{Symbol, Any} = Dict{Symbol, Any}()  # context data from @sim_context
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
    Session

A recording session with metadata and staged scopes.
"""
@kwdef mutable struct Session
    label::String
    root_dir::String           # .simuleos/ path
    stage::Stage
    meta::Dict{String, Any}    # git, julia version, etc.
    simignore_rules::Vector{Dict{Symbol, Any}} = Dict{Symbol, Any}[]

    # Settings cache (reset at @sim_session start, populated lazily)
    # Uses :__MISSING__ sentinel for UXLayers misses to avoid repeated calls
    _settings_cache::Dict{String, Any} = Dict{String, Any}()
end

# =============================================================================
# Git Types
# =============================================================================

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

# =============================================================================
# Registry Types (stubs)
# =============================================================================

"""
    SimuleosHome

Represents the ~/.simuleos home directory with registry and config.
"""
@kwdef mutable struct SimuleosHome
    path::String
    # Future: registry, config, etc.
end

# =============================================================================
# Traceability Types (stubs)
# =============================================================================

"""
    ContextLink

Links an output artifact (hash/path) to its generation context.
"""
@kwdef struct ContextLink
    artifact_hash::String
    artifact_path::Union{Nothing, String} = nothing
    session_label::String
    commit_label::String
    timestamp::DateTime
end
