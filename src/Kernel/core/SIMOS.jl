# ==================================
# Global State — SIMOS
# ==================================

# Single global: SIMOS[].
const SIMOS = Ref{Union{Nothing, SimOs}}(nothing)

"""
    set_sim!(new_sim::SimOs)

I3x — writes `SIMOS[]`

Replace the global SimOs instance. Used for testing.
"""
function set_sim!(new_sim::SimOs)
    SIMOS[] = new_sim
    return SIMOS[]
end

"""
    reset_sim!()

I3x — writes `SIMOS[]`

Reset the global SimOs instance to nothing.
"""
function reset_sim!()
    SIMOS[] = nothing
    return nothing
end

"""
    _get_sim()

I3x — reads `SIMOS[]`

Get the current SimOs instance, error if not activated.
"""
function _get_sim()::SimOs
    sim = SIMOS[]
    isnothing(sim) && error("No Simuleos instance active. Call Simuleos.sim_activate() first.")
    return sim
end

"""
    sim_activate(path::String, args::Dict{String, Any})

I3x — reads/writes `SIMOS[]`, `SIMOS[].project_root`, `SIMOS[]._project`, `SIMOS[].ux`

Activate a project at the given path with settings args.
Sets `SIMOS[]`, invalidates lazy state, and builds settings sources.

# Arguments
- `path`: Path to the project directory (must contain .simuleos/project.json)
- `args`: Settings overrides (highest priority source)
"""
function sim_activate(path::String, args::Dict{String, Any})
    isfile(path) && error("Project path must not be a file: $path")

    validate_project_folder(path)

    # Create or update SimOs
    sim = SIMOS[]
    if isnothing(sim)
        sim = SimOs()
        SIMOS[] = sim
    end

    sim.project_root = path
    sim._project = nothing  # Invalidate lazy project

    # Build settings sources
    _buildux!(sim, args)

    return nothing
end

"""
    sim_activate_jl(args::Dict{String, Any})

I3x — via `sim_activate`

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

I3x — via `sim_activate`

Auto-detect and activate a project from the current working directory.
Searches upward for a .simuleos directory. Uses empty args.
"""
function sim_activate()
    root = find_project_root(pwd())
    if isnothing(root)
        @warn "No Simuleos project found in current directory or parents"
        return nothing
    end
    sim_activate(root, Dict{String, Any}())
    return nothing
end

"""
    project(sim::SimOs)

I2x — reads `sim._project`, `sim.project_root`

Get the Project for an explicit SimOs instance. Lazily initializes if needed.
"""
function project(sim::SimOs)::Project
    isnothing(sim._project) || return sim._project
    isnothing(sim.project_root) && error("No project activated. Use Simuleos.sim_activate(path) first.")

    # Load project id from project.json
    pjpath = project_json_path(sim.project_root)
    pjdata = open(pjpath, "r") do io
        JSON3.read(io, Dict{String, Any})
    end
    id = get(pjdata, "id", nothing)
    isnothing(id) && error("project.json is missing 'id' field: $pjpath")

    sim._project = Project(
        id = id,
        root_path = sim.project_root,
        simuleos_dir = simuleos_dir(sim.project_root)
    )
    return sim._project
end

"""
    project()

I3x — via `_get_sim()`, `project(sim)`

Get the current active Project. Lazily initializes if needed.
"""
function project()::Project
    project(_get_sim())
end

