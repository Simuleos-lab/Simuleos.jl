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
- `path`: Path to the project directory (must contain .simuleos/project.json)
- `args`: Settings overrides (highest priority source)
"""
function sim_activate(path::String, args::Dict{String, Any})
    isfile(path) && error("Project path must not be a file: $path")

    Core.validate_project_folder(path)

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
    sim_activate_jl(args::Dict{String, Any})

Activate a project based on the currently active Julia environment.
- Uses `Base.activate_project()` to get the active environment path.
- Validates that it's not a global environment.
"""
function sim_activate_jl(args::Dict{String, Any})
    jl_proj = Base.activate_project()
    jl_proj in Base.DEPOT_PATH && error("Global environment cannot be used as a Simuleos project. Please activate a local project with a .simuleos/ directory.")
    path = dirname(jl_proj)
    sim_activate(path, args)
end

"""
    sim_activate()

Auto-detect and activate a project from the current working directory.
Searches upward for a .simuleos directory. Uses empty args.
"""
function sim_activate()
    root = Core.find_project_root(pwd())
    if isnothing(root)
        @warn "No Simuleos project found in current directory or parents"
        return nothing
    end
    Core.sim_activate(root, Dict{String, Any}())
    return nothing
end

"""
    project(sim::SimOs)

Get the Project for an explicit SimOs instance. Lazily initializes if needed.
"""
function project(sim::Core.SimOs)::Core.Project
    isnothing(sim._project) || return sim._project
    isnothing(sim.project_root) && error("No project activated. Use Simuleos.sim_activate(path) first.")

    # Load project id from project.json
    pjpath = Core.project_json_path(sim.project_root)
    pjdata = open(pjpath, "r") do io
        JSON3.read(io, Dict{String, Any})
    end
    id = get(pjdata, "id", nothing)
    isnothing(id) && error("project.json is missing 'id' field: $pjpath")

    sim._project = Core.Project(
        id = id,
        root_path = sim.project_root,
        simuleos_dir = Core.simuleos_dir(sim.project_root)
    )
    return sim._project
end

"""
    project()

Get the current active Project. Lazily initializes if needed.
Uses the global SimOs instance.
"""
function project()::Core.Project
    Core.project(Core._get_sim())
end

