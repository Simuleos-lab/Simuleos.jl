# ============================================================
# project.jl — SimuleosProject management
# ============================================================

import JSON3

"""
    _read_json_file(path::String) -> Dict{String, Any}

Read a JSON file and return as a Dict with String keys.
"""
function _read_json_file(path::String)
    raw = open(path, "r") do io
        JSON3.read(io, Dict)
    end
    return _string_keys(raw)
end

function _read_json_file_or_empty(path::String)::Dict{String, Any}
    isfile(path) || return Dict{String, Any}()
    return _read_json_file(path)
end

"""
    _write_json_file(path::String, data)

Write data as pretty-printed JSON.
"""
function _write_json_file(path::String, data)
    ensure_dir(dirname(path))
    open(path, "w") do io
        JSON3.pretty(io, data)
    end
end

"""
    proj_init_at(root_path::String) -> SimuleosProject

Initialize or load a project at the given path.
Creates `.simuleos/project.json` if it doesn't exist.
"""
function proj_init_at(root_path::String)
    root = abspath(root_path)
    sim_dir = _simuleos_dir(root)
    pj_path = project_json_path(sim_dir)

    if isfile(pj_path)
        # Load existing project
        data = _read_json_file(pj_path)
        id = get(data, "id", nothing)
    else
        # Create new project
        ensure_dir(sim_dir)
        id = string(UUIDs.uuid4())
        _write_json_file(pj_path, Dict("id" => id))
    end

    # Ensure subdirectories
    ensure_dir(blobs_dir(sim_dir))
    ensure_dir(sessions_dir(sim_dir))

    return SimuleosProject(;
        id = id,
        root_path = root,
        simuleos_dir = sim_dir,
    )
end

"""
    proj_find_and_init(start_path::String) -> Union{SimuleosProject, Nothing}

Search upward from `start_path` for an existing `.simuleos/project.json`.
Returns initialized project or `nothing`.
"""
function proj_find_and_init(start_path::String)
    sim_dir = find_simuleos_dir(start_path)
    isnothing(sim_dir) && return nothing
    root = dirname(sim_dir)
    return proj_init_at(root)
end

"""
    project_settings(proj::SimuleosProject) -> Dict{String, Any}

Load settings from project's `.simuleos/settings.json`, or empty Dict.
"""
function project_settings(proj::SimuleosProject)
    path = settings_path(proj)
    return _read_json_file_or_empty(path)
end

settings_path(project::SimuleosProject)::String = settings_json_path(project.simuleos_dir)
blob_path(project::SimuleosProject, sha1::String)::String = blob_path(project.blobstorage, sha1)

function find_project_root(start_path::String)::Union{String, Nothing}
    sim_dir = find_simuleos_dir(start_path)
    return isnothing(sim_dir) ? nothing : dirname(sim_dir)
end

function resolve_project(path::String)::SimuleosProject
    root = abspath(path)
    sim_dir = _simuleos_dir(root)
    if isfile(project_json_path(sim_dir))
        return proj_init_at(root)
    end

    found_root = find_project_root(root)
    isnothing(found_root) && error("Could not resolve project from path: $path")
    return proj_init_at(found_root)
end

function _explicit_project_root(simos::SimOs)::Union{Nothing, String}
    for candidate in (
            get(simos.bootstrap, "project.root", nothing),
            env_project_root()
        )
        if candidate isa String && !isempty(strip(candidate))
            return candidate
        end
    end
    return nothing
end

function proj_init!(simos::SimOs)::Union{Nothing, SimuleosProject}
    explicit_root = _explicit_project_root(simos)
    if explicit_root isa String
        mkpath(explicit_root)
        proj = proj_init_at(explicit_root)
        simos.project = proj
        return proj
    end

    proj = proj_find_and_init(pwd())
    if isnothing(proj)
        simos.project = nothing
        @warn "Simuleos: No .simuleos project found from $(pwd()). Recording will not be available."
        return nothing
    end

    simos.project = proj
    return proj
end

function _session_timestamp(meta::Dict{String, Any})::Dates.DateTime
    raw = get(meta, SESSION_META_TIMESTAMP_KEY, nothing)
    raw isa String || return Dates.DateTime(0)
    try
        return Dates.DateTime(raw)
    catch
        return Dates.DateTime(0)
    end
end

function _session_meta(raw::Dict{String, Any})::Dict{String, Any}
    meta = get(raw, SESSION_FILE_META_KEY, Dict{String, Any}())
    meta isa AbstractDict || return Dict{String, Any}()
    return _string_keys(meta)
end

function _session_labels(raw::Dict{String, Any})::Vector{String}
    labels = get(raw, SESSION_FILE_LABELS_KEY, Any[])
    labels isa AbstractVector || return String[]
    return String[string(x) for x in labels]
end

function scan_project_sessions(callback::Function, proj::SimuleosProject)::Nothing
    sdir = sessions_dir(proj.simuleos_dir)
    isdir(sdir) || return nothing

    for entry in readdir(sdir)
        sjson = session_json_path(proj, entry)
        isfile(sjson) || continue
        raw = _read_json_file(sjson)
        callback(raw)
    end
    return nothing
end

function resolve_session_id(proj::SimuleosProject, session_id::Base.UUID)::Base.UUID
    sjson = session_json_path(proj, session_id)
    isfile(sjson) || error("Session not found: $(session_id)")
    return session_id
end

function _normalize_session_label(label::AbstractString)::String
    stripped = strip(String(label))
    isempty(stripped) && error("Session label cannot be empty.")
    return stripped
end

function find_session_id(proj::SimuleosProject, label::AbstractString)::Union{Nothing, Base.UUID}
    stripped = _normalize_session_label(label)

    best = nothing
    best_ts = Dates.DateTime(0)
    scan_project_sessions(proj) do raw
        labels = _session_labels(raw)
        isempty(labels) && return
        labels[1] == stripped || return
        ts = _session_timestamp(_session_meta(raw))
        if isnothing(best) || ts > best_ts
            best = raw
            best_ts = ts
        end
    end

    isnothing(best) && return nothing
    return UUIDs.UUID(String(best[SESSION_FILE_ID_KEY]))
end

function resolve_session_id(proj::SimuleosProject, label::AbstractString)::Base.UUID
    normalized_label = _normalize_session_label(label)
    sid = find_session_id(proj, normalized_label)
    isnothing(sid) && error("Session not found for label: $(normalized_label)")
    return sid
end
