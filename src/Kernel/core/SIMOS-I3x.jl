# SIMOS global state and entrypoints (all I3x - uses SIMOS[])

# Single global: SIMOS[].
const SIMOS = Ref{Union{Nothing, SimOs}}(nothing)

"""
    set_sim!(new_sim::SimOs)

I3x - writes `SIMOS[]`

Replace the global SimOs instance. Used for testing.
"""
function set_sim!(new_sim::SimOs)
    SIMOS[] = new_sim
    return SIMOS[]
end

"""
    reset_sim!()

I3x - writes `SIMOS[]`

Reset the global SimOs instance to nothing.
"""
function reset_sim!()
    SIMOS[] = nothing
    return nothing
end

"""
    _get_sim()

I3x - reads `SIMOS[]`

Get the current SimOs instance, error if not activated.
"""
function _get_sim()::SimOs
    sim = SIMOS[]
    isnothing(sim) && error("No Simuleos instance active. Call Simuleos.sim_activate() first.")
    return sim
end

"""
    sim_activate(path::String, args::Dict{String, Any})

I3x - reads/writes `SIMOS[]`, `SIMOS[].project_root`, `SIMOS[].project`, `SIMOS[].ux`

Activate a project at the given path with settings args.
Sets `SIMOS[]`, builds active `Project`, and builds settings sources.

# Arguments
- `path`: Path to the project directory (must contain .simuleos/project.json)
- `args`: Settings overrides (highest priority source)
"""
function sim_activate(path::String, args::Dict{String, Any})
    path = abspath(path)
    isfile(path) && error("Project path must not be a file: $path")

    proj_validate_folder(path)

    # Create or update SimOs
    sim = SIMOS[]
    if isnothing(sim)
        sim = SimOs()
        SIMOS[] = sim
    end

    sim.project_root = path
    sim.project = _load_project(path)

    # Build settings sources
    _buildux!(sim, args)

    return nothing
end

"""
    sim_activate_jl(args::Dict{String, Any})

I3x - via `sim_activate`

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

I3x - via `sim_activate`

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
    sim_project()

I3x - via `_get_sim()`, `sim_project(sim)`

Get the current active Project.
"""
function sim_project()::Project
    sim_project(_get_sim())
end
