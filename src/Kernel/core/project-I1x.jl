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
    _ = simos
    return resolve_project(proj_path)
end

"""
    resolve_project(proj_path::String)::SimuleosProject

I1x — reads disk, no writes

Resolve a project from `proj_path`.
- If `proj_path` is a `.simuleos` directory path, treat it as explicit project storage path and use its parent as project root.
- Otherwise, walks upward from `proj_path` to find `.simuleos/project.json`.
- If found, loads via `_load_project`.
- Otherwise, creates an in-memory `SimuleosProject` with a fresh UUID.
"""
function resolve_project(
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

function _session_timestamp(meta::Dict{String, Any})::Dates.DateTime
    raw = get(meta, "timestamp", nothing)
    raw isa String || return Dates.DateTime(0)
    try
        return Dates.DateTime(raw)
    catch
        return Dates.DateTime(0)
    end
end

function _session_meta(raw::Dict{String, Any})::Dict{String, Any}
    return Dict{String, Any}(get(raw, "meta", Dict{String, Any}()))
end

function _session_labels(raw::Dict{String, Any})::Vector{String}
    labels_any = get(raw, "labels", Any[])
    labels_any isa AbstractVector || return String[]
    return String[string(label) for label in labels_any]
end

function scan_project_sessions(
        f::Function,
        project::SimuleosProject
    )::Nothing
    sessions_dir = _sessions_dir(project.simuleos_dir)
    isdir(sessions_dir) || return nothing

    for session_name in readdir(sessions_dir)
        session_json = joinpath(sessions_dir, session_name, "session.json")
        isfile(session_json) || continue
        raw = open(session_json, "r") do io
            JSON3.read(io, Dict{String, Any})
        end
        f(raw)
    end
    return nothing
end

function resolve_session_id(
        project::SimuleosProject,
        session_id::Base.UUID
    )::Base.UUID
    session_json = session_json_path(project, session_id)
    isfile(session_json) || error("Session not found: $(session_id)")
    return session_id
end

function resolve_session_id(
        project::SimuleosProject,
        first_label::String
    )::Base.UUID
    stripped_label = strip(first_label)
    isempty(stripped_label) && error("Session label cannot be empty.")

    matches = Tuple{Base.UUID, Dates.DateTime}[]
    scan_project_sessions(project) do raw
        haskey(raw, "session_id") || return
        session_id_raw = raw["session_id"]
        session_id_raw isa String || return

        labels = _session_labels(raw)
        isempty(labels) && return
        labels[1] == stripped_label || return

        meta = _session_meta(raw)
        push!(matches, (UUIDs.UUID(session_id_raw), _session_timestamp(meta)))
    end

    isempty(matches) && error("No session found for first label \"$(stripped_label)\".")
    sort!(matches; by=t -> (t[2], string(t[1])))
    return matches[end][1]
end
