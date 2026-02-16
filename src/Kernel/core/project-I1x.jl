# Project driver methods (all I1x - explicit subsystem objects)

proj_path(project::SimuleosProject)::String = project.root_path
simuleos_dir(project::SimuleosProject)::String = project.simuleos_dir
proj_json_path(project::SimuleosProject)::String = _proj_json_path(project.root_path)
settings_path(project::SimuleosProject)::String = _proj_settings_path(project.root_path)
tape_path(project::SimuleosProject, session_id::Base.UUID)::String = tape_path(project.simuleos_dir, session_id)
session_json_path(project::SimuleosProject, session_id::Base.UUID)::String = _session_json_path(project.simuleos_dir, session_id)

blob_path(project::SimuleosProject, sha1::String)::String = blob_path(project.blobstorage, sha1)

function _is_simuleos_dir_path(path::String)::Bool
    return basename(normpath(path)) == SIMULEOS_DIR_NAME
end

"""
    resolve_project(simos::SimOs, proj_path::String)::SimuleosProject

I1x — reads disk, no writes

Resolve a project from `proj_path`.
- If `proj_path` is a `.simuleos` directory path, treat it as explicit project storage path and use its parent as project root.
- Otherwise, walks upward from `proj_path` to find `.simuleos/project.json`.
- If found, loads via `_load_project`.
- Otherwise, creates an in-memory `SimuleosProject` with a fresh UUID.
"""
function resolve_project(
        simos::SimOs,
        proj_path::String
    )::SimuleosProject
    proj_path = abspath(proj_path)
    isfile(proj_path) && error("Project path must not be a file: $proj_path")

    # Resolve project root
    proj_root = if _is_simuleos_dir_path(proj_path)
        dirname(proj_path)
    else
        something(find_project_root(proj_path), proj_path)
    end

    pjpath = _proj_json_path(proj_root)
    if isfile(pjpath)
        return _load_project(proj_root)
    end
    # Fresh project — in-memory only, no disk writes
    return SimuleosProject(
        id = string(UUIDs.uuid4()),
        root_path = proj_root,
    )
end
