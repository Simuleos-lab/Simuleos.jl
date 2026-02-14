# Project initialization entrypoints (all I3x - uses SIMOS via sim_activate)

"""
    sim_init(proj_path::String; bootstrap::Dict{String, Any} = Dict{String, Any}())

I3x - via `sim_activate` -> writes `SIMOS[]`

Initialize a Simuleos project at `proj_path`.
- Creates `.simuleos/project.json` with a unique project UUID.
- Idempotent: if `project.json` already exists, preserves it.
- Calls `sim_activate(proj_path, bootstrap)` at the end.
"""
function sim_init(proj_path::String; bootstrap::Dict{String, Any} = Dict{String, Any}())
    proj_root = abspath(proj_path)
    isfile(proj_root) && error("Project path must not be a file: $proj_root")

    # init home
    home = SimuleosHome(
        path = get(bootstrap, "homePath", simuleos_home_default_path())
    )
    init_home(home)

    # init project
    proj = Project(root_path = proj_root)
    already_init = proj_is_init(proj)
    proj_init!(proj)

    if already_init
        @info "Project already initialized, activating..." proj_json=proj_json_path(proj)
    else
        @info "Simuleos project initialized at" proj_path=proj_path(proj)
    end

    sim_activate(proj_root, bootstrap)
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
