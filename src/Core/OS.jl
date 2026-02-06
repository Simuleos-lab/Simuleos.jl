# ==================================
# SimOS - The God Object
# ==================================

# Global instance (mutable, swappable for testing)
const OS = Core.SimOS()

"""
    set_os!(new_os::Core.SimOS)

Replace the global SimOS instance. Used for testing.
"""
function set_os!(new_os::Core.SimOS)
    # Copy fields from new_os to OS
    Core.OS.home_path = new_os.home_path
    Core.OS.project_root = new_os.project_root
    Core.OS.bootstrap = new_os.bootstrap
    Core.OS._project = new_os._project
    Core.OS._home = new_os._home
    Core.OS._ux_root = new_os._ux_root
    Core.OS._sources = new_os._sources
    return Core.OS
end

"""
    reset_os!()

Reset the global SimOS instance to defaults.
"""
function reset_os!()
    Core.OS.home_path = joinpath(homedir(), ".simuleos")
    Core.OS.project_root = nothing
    Core.OS.bootstrap = Dict{String, Any}()
    Core.OS._project = nothing
    Core.OS._home = nothing
    Core.OS._ux_root = nothing
    Core.OS._sources = Dict{String, Any}[]
    return Core.OS
end

"""
    activate(path::String, args::Dict{String, Any})

Activate a project at the given path with settings args.
Sets OS.project_root, invalidates lazy state, and builds settings sources.

# Arguments
- `path`: Path to the project directory (must contain .simuleos/)
- `args`: Settings overrides (highest priority source)
"""
function activate(path::String, args::Dict{String, Any})
    if !isdir(path)
        error("Project path does not exist: $path")
    end
    simuleos_dir = joinpath(path, ".simuleos")
    if !isdir(simuleos_dir)
        error("Not a Simuleos project (no .simuleos directory): $path")
    end
    Core.OS.project_root = path
    Core.OS._project = nothing  # Invalidate lazy project

    # Build settings sources
    Core._build_ux_root!(Core.OS, args)

    return nothing
end

"""
    activate()

Auto-detect and activate a project from the current working directory.
Searches upward for a .simuleos directory. Uses empty args.
"""
function activate()
    path = pwd()
    while true
        simuleos_dir = joinpath(path, ".simuleos")
        if isdir(simuleos_dir)
            activate(path, Dict{String, Any}())
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
    if isnothing(Core.OS._project)
        if isnothing(Core.OS.project_root)
            error("No project activated. Use Simuleos.activate(path) first.")
        end
        Core.OS._project = Core.Project(
            root_path = Core.OS.project_root,
            simuleos_dir = joinpath(Core.OS.project_root, ".simuleos")
        )
    end
    return Core.OS._project
end

"""
    home()

Get the SimuleosHome instance. Lazily initializes if needed.
"""
function home()::Core.SimuleosHome
    if isnothing(Core.OS._home)
        Core.OS._home = Registry.init_home(Core.OS.home_path)
    end
    return Core.OS._home
end
