# Project driver methods for SimOs (all I2x - explicit SimOs, accesses fields)

# NOTE: uncomment when sim_project/sim_home accessors are available
# proj_json_path(sim::SimOs)::String = proj_json_path(sim_project(sim))
# proj_settings_path(sim::SimOs)::String = settings_path(sim_project(sim))
# home_settings_path(sim::SimOs)::String = settings_path(sim_home(sim))

"""
    resolve_project(simos::SimOs)::SimuleosProject

I2x — reads settings, writes bootstrap

Resolve the local project from UX settings.
- Reads `projPath` setting (defaults to `pwd()`).
- Delegates to `resolve_project(simos, proj_path)` for root discovery.
- Writes resolved `projRoot` back to bootstrap.
"""
function resolve_project(
        simos::SimOs
    )::SimuleosProject
    proj_path = settings(simos, "projPath", pwd())
    proj = resolve_project(simos, proj_path)
    UXLayers.update_bootstrap!(ux_root(simos), Dict("projRoot" => proj.root_path))
    return proj
end

"""
    proj_init!(simos::SimOs)

I2x — reads settings, writes simos.project, writes disk

Initialize the project on `simos`.
- Calls `resolve_project(simos)` to read `projPath` and discover root.
- Sets `simos.project`.
- Creates `.simuleos/` and writes `project.json` to disk if missing.
"""
function proj_init!(simos::SimOs)

    # Resolve project (read disk or create in-memory)
    proj = resolve_project(simos)
    simos.project = proj

    # Ensure disk representation exists
    proj_sim = simuleos_dir(proj)
    proj_json = proj_json_path(proj)
    mkpath(proj_sim)

    if !isfile(proj_json)
        open(proj_json, "w") do io
            JSON3.pretty(io, Dict("id" => proj.id))
        end
    end

    return nothing
end
