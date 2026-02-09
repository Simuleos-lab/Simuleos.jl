# ==================================
# Global State — current_sim
# ==================================

# Single global: current_sim[]. No separate session global.
const current_sim = Ref{Union{Nothing, Core.SimOs}}(nothing)

"""
    set_sim!(new_sim::Core.SimOs)

Replace the global SimOs instance. Used for testing.
"""
function set_sim!(new_sim::Core.SimOs)
    Core.current_sim[] = new_sim
    return Core.current_sim[]
end

"""
    reset_sim!()

Reset the global SimOs instance to nothing.
"""
function reset_sim!()
    Core.current_sim[] = nothing
    return nothing
end

"""
    _get_sim()

Get the current SimOs instance, error if not activated.
"""
function _get_sim()::Core.SimOs
    sim = Core.current_sim[]
    isnothing(sim) && error("No Simuleos instance active. Call Simuleos.sim_activate() first.")
    return sim
end

"""
    sim_activate(path::String, args::Dict{String, Any})

Activate a project at the given path with settings args.
Sets `current_sim[]`, invalidates lazy state, and builds settings sources.

# Arguments
- `path`: Path to the project directory (must contain .simuleos/)
- `args`: Settings overrides (highest priority source)
"""
function sim_activate(path::String, args::Dict{String, Any})
    if !isdir(path)
        error("Project path does not exist: $path")
    end
    simuleos_dir = joinpath(path, ".simuleos")
    if !isdir(simuleos_dir)
        error("Not a Simuleos project (no .simuleos directory): $path")
    end

    # Create or update SimOs
    sim = Core.current_sim[]
    if isnothing(sim)
        sim = Core.SimOs()
        Core.current_sim[] = sim
    end

    sim.project_root = path
    sim._project = nothing  # Invalidate lazy project

    # Build settings sources
    Core._buildux!(sim, args)

    return nothing
end

"""
    sim_activate()

Auto-detect and activate a project from the current working directory.
Searches upward for a .simuleos directory. Uses empty args.
"""
function sim_activate()
    path = pwd()
    while true
        simuleos_dir = joinpath(path, ".simuleos")
        if isdir(simuleos_dir)
            Core.sim_activate(path, Dict{String, Any}())
            return nothing
        end
        parent = dirname(path)
        if parent == path  # Reached root
            @warn "No Simuleos project found in current directory or parents"
            return nothing
        end
        path = parent
    end
end

"""
    project()

Get the current active Project. Lazily initializes if needed.
"""
function project()::Core.Project
    sim = Core._get_sim()
    if isnothing(sim._project)
        if isnothing(sim.project_root)
            error("No project activated. Use Simuleos.sim_activate(path) first.")
        end
        sim._project = Core.Project(
            root_path = sim.project_root,
            simuleos_dir = joinpath(sim.project_root, ".simuleos")
        )
    end
    return sim._project
end

"""
    home()

Get the SimuleosHome instance. Lazily initializes if needed.
"""
function home()::Core.SimuleosHome
    sim = Core._get_sim()
    if isnothing(sim._home)
        sim._home = Registry.init_home(sim.home_path)
    end
    return sim._home
end
