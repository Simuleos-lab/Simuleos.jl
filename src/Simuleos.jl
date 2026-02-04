# Simuleos - An Operative System for Simulations
# Main module that wires up all subsystems

module Simuleos

# =============================================================================
# Core Module (must be first - all types defined here)
# =============================================================================
include("Core/Core.jl")
using .Core

# =============================================================================
# App Modules (depend on Core)
# =============================================================================
include("ContextIO/ContextIO.jl")
include("FileSystem/FileSystem.jl")
include("Registry/Registry.jl")
include("Tools/Tools.jl")
include("Traceability/Traceability.jl")

# Import git functions for re-export (backward compatibility)
using .Core: git_hash, git_dirty, git_describe, git_branch, git_remote, git_init
using .Core: hash, dirty, describe, branch, remote, init

# Import ContextIO functions for re-export
using .ContextIO: simignore!, set_simignore_rules!, _should_ignore
using .ContextIO: RootHandler, SessionHandler, TapeHandler, BlobHandler
using .ContextIO: sessions, tape, blob, exists
using .ContextIO: CommitWrapper, ScopeWrapper, VariableWrapper, BlobWrapper
using .ContextIO: session_label, commit_label, metadata, scopes, blob_refs
using .ContextIO: label, timestamp, variables, labels, data
using .ContextIO: name, src_type, value, blob_ref, src
using .ContextIO: iterate_raw_tape, iterate_tape, load_raw_blob, load_blob

# =============================================================================
# SimOS - The God Object
# =============================================================================

# Global instance (mutable, swappable for testing)
const OS = Core.SimOS()

"""
    set_os!(new_os::SimOS)

Replace the global SimOS instance. Used for testing.
"""
function set_os!(new_os::Core.SimOS)
    # Copy fields from new_os to OS
    OS.home_path = new_os.home_path
    OS.project_root = new_os.project_root
    OS._project = new_os._project
    OS._home = new_os._home
    return OS
end

"""
    reset_os!()

Reset the global SimOS instance to defaults.
"""
function reset_os!()
    OS.home_path = joinpath(homedir(), ".simuleos")
    OS.project_root = nothing
    OS._project = nothing
    OS._home = nothing
    return OS
end

"""
    activate(path::String)

Activate a project at the given path.
Sets OS.project_root and invalidates lazy state.
"""
function activate(path::String)
    if !isdir(path)
        error("Project path does not exist: $path")
    end
    simuleos_dir = joinpath(path, ".simuleos")
    if !isdir(simuleos_dir)
        error("Not a Simuleos project (no .simuleos directory): $path")
    end
    OS.project_root = path
    OS._project = nothing  # Invalidate lazy project
    return nothing
end

"""
    activate()

Auto-detect and activate a project from the current working directory.
Searches upward for a .simuleos directory.
"""
function activate()
    path = pwd()
    while true
        simuleos_dir = joinpath(path, ".simuleos")
        if isdir(simuleos_dir)
            OS.project_root = path
            OS._project = nothing
            return nothing
        end
        parent = dirname(path)
        if parent == path  # Reached root
            error("No Simuleos project found in current directory or parents")
        end
        path = parent
    end
end

"""
    project()

Get the current active Project. Lazily initializes if needed.
"""
function project()::Core.Project
    if isnothing(OS._project)
        if isnothing(OS.project_root)
            error("No project activated. Use Simuleos.activate(path) first.")
        end
        OS._project = Core.Project(
            root_path = OS.project_root,
            simuleos_dir = joinpath(OS.project_root, ".simuleos")
        )
    end
    return OS._project
end

"""
    home()

Get the SimuleosHome instance. Lazily initializes if needed.
"""
function home()::Core.SimuleosHome
    if isnothing(OS._home)
        OS._home = Registry.init_home(OS.home_path)
    end
    return OS._home
end

# =============================================================================
# Convenience Re-exports (for backward compatibility during transition)
# =============================================================================

# Core types (commonly used)
export SimOS, Project, Session, Stage, Scope, ScopeVariable
export GitHandler, SimuleosHome, ContextLink

# SimOS functions
export set_os!, reset_os!, activate, project, home

# ContextIO macros (most common user-facing API)
export @sim_session, @sim_store, @sim_context, @sim_capture, @sim_commit

# ContextIO query (commonly used)
export RootHandler, SessionHandler, TapeHandler, BlobHandler
export sessions, tape, blob, exists
export CommitWrapper, ScopeWrapper, VariableWrapper, BlobWrapper
export session_label, commit_label, metadata, scopes, blob_refs
export label, timestamp, variables, labels, data
export name, src_type, value, blob_ref, src
export iterate_raw_tape, iterate_tape, load_raw_blob, load_blob

# Simignore
export simignore!, set_simignore_rules!, _should_ignore

# Git functions (backward compatibility)
export git_hash, git_dirty, git_describe, git_branch, git_remote, git_init
export hash, dirty, describe, branch, remote, init

end # module Simuleos
