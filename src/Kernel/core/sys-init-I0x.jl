# Project initialization validation (all I0x - pure path checks)

"""
    proj_validate_folder(proj_path::String)

I0x - pure path validation

Validate that `proj_path` is a Simuleos project.
Checks that `.simuleos/project.json` exists.
"""
function proj_validate_folder(proj_path::String)
    pjpath = _proj_json_path(proj_path)
    if !isfile(pjpath)
        error("Not a Simuleos project (no .simuleos/project.json): $proj_path\n" *
              "Run `Simuleos.sim_init(\"$proj_path\")` first.")
    end
    return nothing
end
