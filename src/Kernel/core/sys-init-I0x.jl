# Project initialization validation (all I0x - pure path checks)

"""
    proj_validate_folder(path::String)

I0x - pure path validation

Validate that `path` is a Simuleos project.
Checks that `.simuleos/project.json` exists.
"""
function proj_validate_folder(path::String)
    pjpath = project_json_path(path)
    if !isfile(pjpath)
        error("Not a Simuleos project (no .simuleos/project.json): $path\n" *
              "Run `Simuleos.sim_init(\"$path\")` first.")
    end
    return nothing
end
