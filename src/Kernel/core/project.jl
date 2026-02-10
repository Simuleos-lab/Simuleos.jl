# Project structure: path helpers and project root discovery
# All .simuleos/ directory layout knowledge lives here

# ==================================
# Path Helpers (all I0x — pure path construction)
# ==================================

local_settings_path(project_root::String)::String = joinpath(simuleos_dir(project_root), "settings.json")

function _sessions_dir(root::RootHandler)
    joinpath(root.path, "sessions")
end

function _session_dir(session::SessionHandler)
    safe_label = replace(session.label, r"[^\w\-]" => "_")
    joinpath(_sessions_dir(session.root), safe_label)
end

function _tape_path(tape::TapeHandler)
    joinpath(_session_dir(tape.session), "tapes", TAPE_FILENAME)
end

function _blob_path(root_dir::String, sha1::String)
    joinpath(root_dir, "blobs", "$(sha1)$(BLOB_EXT)")
end

function _blob_path(bh::BlobHandler)
    _blob_path(bh.root.path, bh.sha1)
end

# ==================================
# Project Root Discovery
# ==================================

"""
    find_project_root(start_path::String) -> Union{String, Nothing}

I0x — pure directory traversal

Search upward from `start_path` for a `.simuleos/` directory.
Returns the containing directory (the project root), or `nothing` if not found.
"""
function find_project_root(start_path::String)::Union{String, Nothing}
    path = abspath(start_path)
    while true
        if isdir(simuleos_dir(path))
            return path
        end
        parent = dirname(path)
        if parent == path  # Reached filesystem root
            return nothing
        end
        path = parent
    end
end
