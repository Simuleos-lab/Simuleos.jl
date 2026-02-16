# Project path helpers and root discovery (all I0x - pure path utilities)

# Bootstrap-only project settings path.
_proj_settings_path(project_root::String)::String = joinpath(_simuleos_dir(project_root), "settings.json")
_sessions_dir(simuleos_dir::String)::String = joinpath(simuleos_dir, "sessions")
_session_dir(simuleos_dir::String, session_id::Base.UUID)::String = joinpath(_sessions_dir(simuleos_dir), string(session_id))
_scopetapes_dir(simuleos_dir::String, session_id::Base.UUID)::String = joinpath(_session_dir(simuleos_dir, session_id), "scopetapes")
tape_path(simuleos_dir::String, session_id::Base.UUID)::String = joinpath(_scopetapes_dir(simuleos_dir, session_id), TAPE_FILENAME)

"""
    _proj_validate_folder(proj_path::String)

I0x - pure path validation

Validate that `proj_path` is a Simuleos project.
"""
function _proj_validate_folder(proj_path::String)
    pjpath = _proj_json_path(proj_path)
    if !isfile(pjpath)
        error("Not a Simuleos project (no .simuleos/project.json): $proj_path\n" *
              "Run `Simuleos.sim_init(\"$proj_path\")` first.")
    end
    return nothing
end

function _load_project(proj_path::String)::SimuleosProject
    pjpath = _proj_json_path(proj_path)
    pjdata = open(pjpath, "r") do io
        JSON3.read(io, Dict{String, Any})
    end

    id = get(pjdata, "id", nothing)
    isnothing(id) && error("project.json is missing 'id' field: $pjpath")

    sd = _simuleos_dir(proj_path)
    return SimuleosProject(
        id = string(id),
        root_path = proj_path,
        simuleos_dir = sd,
        blobstorage = BlobStorage(sd)
    )
end

"""
    resolve_project(simos::SimOs, proj_root::String)::SimuleosProject

I0x - reads disk, no writes

Resolve the project state from `proj_root`.
- If `.simuleos/project.json` exists on disk, loads it via `_load_project`.
- Otherwise, creates an in-memory `SimuleosProject` with a fresh UUID.
Caller is responsible for path normalization.
"""
function resolve_project(
        simos::SimOs,
        proj_path::String
    )::SimuleosProject
    proj_path = abspath(proj_path)
    isfile(proj_path) && error("Project path must not be a file: $proj_path")

    # Walk upward to find project root, fall back to proj_path itself
    proj_root = something(find_project_root(proj_path), proj_path)

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

function resolve_project(
        simos::SimOs
    )::SimuleosProject
    proj_path = settings(simos, "projPath", pwd())
    proj = resolve_project(simos, proj_path)
    UXLayers.update_bootstrap!(ux_root(simos), Dict("projRoot" => proj.root_path))
    return proj
end
# Resolve proj_root from settings

# Project identity file path (used by sys-init and SIMOS)
_proj_json_path(project_root::String)::String = joinpath(_simuleos_dir(project_root), "project.json")

function blob_path(storage::BlobStorage, sha1::String)::String
    joinpath(storage.root_dir, "blobs", "$(sha1)$(BLOB_EXT)")
end

"""
    find_project_root(start_path::String) -> Union{String, Nothing}

I0x - pure directory traversal

Search upward from `start_path` for a `.simuleos/` directory.
Returns the containing directory (the project root), or `nothing` if not found.
"""
function find_project_root(start_path::String)::Union{String, Nothing}
    path = abspath(start_path)
    while true
        if isfile(_proj_json_path(path))
            return path
        end
        parent = dirname(path)
        if parent == path  # Reached filesystem root
            return nothing
        end
        path = parent
    end
end
