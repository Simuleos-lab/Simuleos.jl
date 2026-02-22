# ============================================================
# simos.jl — SimOs global state management
# ============================================================

"""
    _get_sim() -> SimOs

Get the current global SimOs instance. Throws if uninitialized.
"""
function _get_sim()
    sim = SIMOS[]
    isnothing(sim) && error("Simuleos not initialized. Call `sim_init!()` first.")
    return sim
end

"""
    _get_sim_or_nothing() -> Union{SimOs, Nothing}

Get the current global SimOs instance, or nothing.
"""
_get_sim_or_nothing() = SIMOS[]

"""
    sim_project() -> SimuleosProject

Get the project from the current global SimOs. Throws if no project.
"""
function sim_project()
    sim = _get_sim()
    isnothing(sim.project) && error("No active project. Ensure sim_init!() found a .simuleos directory.")
    return sim.project
end

"""
    sim_project(simos::SimOs) -> SimuleosProject

Get the project from a SimOs instance.
"""
function sim_project(simos::SimOs)
    isnothing(simos.project) && error("No active project.")
    return simos.project
end

function sim_home()
    sim = _get_sim()
    isnothing(sim.home) && error("No active home.")
    return sim.home
end

function sim_home(simos::SimOs)
    isnothing(simos.home) && error("No active home.")
    return simos.home
end

function set_sim!(new_sim::SimOs)
    SIMOS[] = new_sim
    return new_sim
end

"""
    sim_init!(; bootstrap::Dict = Dict{String, Any}()) -> SimOs

Initialize the global Simuleos system.

1. Creates a fresh SimOs
2. Initializes the home directory (~/.simuleos/)
3. Searches for a project (.simuleos/project.json) starting from pwd
4. Loads and merges settings from all layers
"""
function sim_init!(; bootstrap::Dict = Dict{String, Any}())
    simos = SimOs(; bootstrap = Dict{String, Any}(string(k) => v for (k, v) in bootstrap))

    # Phase 1: Home
    home_init!(simos)

    # Phase 2: Project
    proj_init!(simos)

    # Phase 3: Settings
    simos.settings = load_all_settings(simos)

    # Phase 4: Git handler
    if !isnothing(simos.project)
        simos.project.git_handler = _git_handler_for(simos.project.root_path)
    end

    # Activate
    return set_sim!(simos)
end

"""
    sim_reset!()

Reset the global SimOs to nothing.
"""
function sim_reset!()
    SIMOS[] = nothing
    return nothing
end

function reset!(simos::SimOs)
    simos.worksession = nothing
    return simos
end

function nuke!(simos::SimOs)
    if !isnothing(simos.project)
        rm(simos.project.simuleos_dir; recursive=true, force=true)
    end
    simos.worksession = nothing
    return simos
end
