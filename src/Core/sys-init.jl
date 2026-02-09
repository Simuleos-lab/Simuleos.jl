# ==================================
# sim_init — Project Initialization
# ==================================

"""
    sim_init(path::String; args::Dict{String, Any} = Dict{String, Any}())

Initialize a Simuleos project at `path`.
- Creates `.simuleos/project.json` with a unique project UUID.
- Idempotent: if `project.json` already exists, preserves it.
- Calls `sim_activate(path, args)` at the end.
"""
function sim_init(path::String; args::Dict{String, Any} = Dict{String, Any}())
    sd = Core.simuleos_dir(path)
    pjpath = Core.project_json_path(path)

    if isfile(pjpath)
        @info "Project already initialized, activating..." path
    else
        mkpath(sd)
        open(pjpath, "w") do io
            JSON3.pretty(io, Dict("id" => string(UUIDs.uuid4())))
        end
        @info "Simuleos project initialized at $path"
    end

    Core.sim_activate(path, args)
    return nothing
end

"""
    sim_init(; args::Dict{String, Any} = Dict{String, Any}())

Initialize a Simuleos project at the current working directory.
"""
function sim_init(; args::Dict{String, Any} = Dict{String, Any}())
    Core.sim_init(pwd(); args)
end
