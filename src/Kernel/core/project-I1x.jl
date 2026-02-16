# Project driver methods (all I1x - explicit subsystem objects)

proj_path(project::SimuleosProject)::String = project.root_path
simuleos_dir(project::SimuleosProject)::String = project.simuleos_dir
proj_json_path(project::SimuleosProject)::String = _proj_json_path(project.root_path)
settings_path(project::SimuleosProject)::String = _proj_settings_path(project.root_path)
tape_path(project::SimuleosProject, session_id::Base.UUID)::String = tape_path(project.simuleos_dir, session_id)

blob_path(project::SimuleosProject, sha1::String)::String = blob_path(project.blobstorage, sha1)

"""
    proj_init!(simos::SimOs)

I1x - reads settings, writes disk

Initialize the project on `simos`.
- Reads `projRoot` from UX settings (defaults to `pwd()`).
- Calls `resolve_project` to build/load the `SimuleosProject`.
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
