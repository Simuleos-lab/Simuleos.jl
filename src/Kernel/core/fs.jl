# ============================================================
# fs.jl — Filesystem path helpers for .simuleos layout
# ============================================================

const SIMULEOS_DIR_NAME = ".simuleos"
const PROJECT_JSON = "project.json"
const SESSION_JSON = "session.json"
const SETTINGS_JSON = "settings.json"
const SESSION_FILE_ID_KEY = "session_id"
const SESSION_FILE_LABELS_KEY = "labels"
const SESSION_FILE_META_KEY = "meta"
const BLOBS_DIR = "blobs"
const SESSIONS_DIR = "sessions"
const TAPES_DIR = "tapes"
const DEFAULT_TAPE_NAME = "main"
const BLOB_EXT = ".jls"

# -- Path builders --

"""Path to project.json inside a .simuleos directory."""
project_json_path(simuleos_dir::String) = joinpath(simuleos_dir, PROJECT_JSON)

"""Path to settings.json inside a .simuleos directory."""
settings_json_path(simuleos_dir::String) = joinpath(simuleos_dir, SETTINGS_JSON)

"""Path to the blobs directory."""
blobs_dir(simuleos_dir::String) = joinpath(simuleos_dir, BLOBS_DIR)

"""Path to the sessions directory."""
sessions_dir(simuleos_dir::String) = joinpath(simuleos_dir, SESSIONS_DIR)

"""Path to a specific session directory."""
_session_dir(simuleos_dir::String, session_id) =
    joinpath(sessions_dir(simuleos_dir), string(session_id))

"""Path to session.json for a specific session."""
session_json_path(proj::SimuleosProject, session_id) =
    _session_json_path(proj.simuleos_dir, session_id)
_session_json_path(simuleos_dir::String, session_id) = joinpath(_session_dir(simuleos_dir, session_id), SESSION_JSON)

"""Path to tapes directory for a session."""
_tapes_dir(simuleos_dir::String, session_id) =
    joinpath(_session_dir(simuleos_dir, session_id), TAPES_DIR)

"""Path to a specific tape directory for a session."""
_tape_dir(simuleos_dir::String, session_id, tape_name::AbstractString = DEFAULT_TAPE_NAME) =
    joinpath(_tapes_dir(simuleos_dir, session_id), String(tape_name))

"""Path to the default tape directory for a session."""
tape_path(simuleos_dir::String, session_id) = _tape_dir(simuleos_dir, session_id, DEFAULT_TAPE_NAME)
tape_path(simuleos_dir::String, session_id, tape_name::AbstractString) =
    _tape_dir(simuleos_dir, session_id, tape_name)

tape_path(proj::SimuleosProject, session_id) = tape_path(proj.simuleos_dir, session_id)
tape_path(proj::SimuleosProject, session_id, tape_name::AbstractString) =
    tape_path(proj.simuleos_dir, session_id, tape_name)

_simuleos_dir(root::String) = joinpath(root, SIMULEOS_DIR_NAME)
simuleos_dir(project::SimuleosProject)::String = project.simuleos_dir

# -- Directory search --

"""
    find_simuleos_dir(start_path::String) -> Union{String, Nothing}

Walk upward from `start_path` looking for a `.simuleos/project.json`.
Returns the `.simuleos` directory path, or `nothing` if not found.
"""
function find_simuleos_dir(start_path::String)
    path = abspath(start_path)
    while true
        candidate = joinpath(path, SIMULEOS_DIR_NAME)
        if isfile(project_json_path(candidate))
            return candidate
        end
        parent = dirname(path)
        parent == path && return nothing  # reached filesystem root
        path = parent
    end
end

"""
    ensure_dir(path::String) -> String

Create directory (and parents) if it doesn't exist. Returns the path.
"""
function ensure_dir(path::String)
    mkpath(path)
    return path
end
