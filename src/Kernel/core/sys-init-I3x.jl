# Project initialization entrypoints (all I3x - uses SIMOS via sim_activate)

"""
    sim_init(proj_path::String; bootstrap::Dict{String, Any} = Dict{String, Any}())

I3x - via `sim_activate` -> writes `SIMOS[]`

Initialize a Simuleos project at `proj_path`.
- Creates `.simuleos/project.json` with a unique project UUID.
- Idempotent: if `project.json` already exists, preserves it.
- Calls `sim_activate(proj_path, bootstrap)` at the end.
"""
function sim_init!(
        simos::SimOs; 
        bootstrap::Dict{String, Any} = Dict{String, Any}()
    )
    
    # Phase 0: init uxlayer
    simos.ux = uxlayer_init(bootstrap)
    # NOTE: from now on, we can use settings(simos, key, default) during init.

    # Phase 1: init home
    home_init!(simos)

    # Phase 2: init project
    proj_init!(simos)

    return nothing
end

"""
    sim_init(; bootstrap::Dict{String, Any} = Dict{String, Any}())

I3x - via `sim_init(proj_path)`

Initialize a Simuleos project at the current working directory.
"""
function sim_init(; bootstrap::Dict{String, Any} = Dict{String, Any}())
    sim_init(pwd(); bootstrap)
end
