# Project path helpers and root discovery (all I0x - pure path utilities)

# Bootstrap-only project settings path.
_proj_settings_path(project_root::String)::String = joinpath(_simuleos_dir(project_root), "settings.json")
tape_path(root_dir::String)::String = joinpath(root_dir, TAPE_FILENAME)

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
