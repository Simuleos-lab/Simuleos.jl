# ============================================================
# WorkSession/session.jl — Session lifecycle management
# ============================================================

"""
    resolve_session(simos::_Kernel.SimOs, proj::_Kernel.SimuleosProject;
                    session_id=nothing, labels=String[]) -> WorkSession

Resolve or create a WorkSession.
- If a session.json exists for the given session_id, load it.
- Otherwise, create a new WorkSession with the given labels.
This is a pure lookup — no side effects on simos or filesystem.
"""
function resolve_session(simos::_Kernel.SimOs, proj::_Kernel.SimuleosProject;
        session_id = nothing,
        labels::Vector{String} = String[]
    )
    sid = isnothing(session_id) ? UUIDs.uuid4() : session_id

    # Try to load existing session
    session_json = _Kernel.session_json_path(proj, sid)
    if isfile(session_json)
        return parse_session(proj, _Kernel._read_json_file(session_json))
    end

    # New session (not persisted yet)
    return _Kernel.WorkSession(; session_id = sid, labels = labels)
end

"""
    resolve_session(proj::_Kernel.SimuleosProject, label::String) -> WorkSession

Resolve a session by label. Scans all session files in the project and
picks the newest one matching the label. Creates a new session if none found.
"""
function resolve_session(proj::_Kernel.SimuleosProject, label::String)
    stripped = _Kernel._normalize_session_label(label)

    sid = _Kernel.find_session_id(proj, stripped)
    isnothing(sid) && return _Kernel.WorkSession(; labels = [stripped])

    session_json = _Kernel.session_json_path(proj, sid)
    return parse_session(proj, _Kernel._read_json_file(session_json))
end

"""
    scan_session_files(callback, proj::_Kernel.SimuleosProject)

Scan all session.json files in a project. Calls `callback(raw_dict)` for each.
"""
function scan_session_files(callback, proj::_Kernel.SimuleosProject)
    return _Kernel.scan_project_sessions(callback, proj)
end

"""
    parse_session(proj::_Kernel.SimuleosProject, raw::Dict) -> WorkSession

Parse a raw session dict into a WorkSession.
"""
function parse_session(proj::_Kernel.SimuleosProject, raw::AbstractDict)
    _ = proj
    payload = _Kernel._string_keys(raw)
    haskey(payload, _Kernel.SESSION_FILE_ID_KEY) || error("Invalid session file: missing `session_id`.")
    return _Kernel.WorkSession(;
        session_id = UUIDs.UUID(string(payload[_Kernel.SESSION_FILE_ID_KEY])),
        labels = _Kernel._session_labels(payload),
        metadata = _Kernel._session_meta(payload),
    )
end

"""
    _persist_session!(proj, ws::_Kernel.WorkSession)

Write session.json to disk.
"""
function _persist_session!(proj::_Kernel.SimuleosProject, ws::_Kernel.WorkSession)
    sjson = _Kernel._session_json_path(proj.simuleos_dir, ws.session_id)
    _Kernel._write_json_file(sjson, Dict(
        _Kernel.SESSION_FILE_ID_KEY => string(ws.session_id),
        _Kernel.SESSION_FILE_LABELS_KEY => ws.labels,
        _Kernel.SESSION_FILE_META_KEY => ws.metadata,
    ))
    # Ensure tapes dir exists
    _Kernel.ensure_dir(_Kernel._tapes_dir(proj.simuleos_dir, ws.session_id))
end

"""
    isdirty(simos, ws::_Kernel.WorkSession) -> Bool

Check if the work session has un-committed captures.
"""
function isdirty(simos, ws::_Kernel.WorkSession)
    return !isempty(ws.stage.captures)
end

"""
    session_init!(simos::_Kernel.SimOs, proj::_Kernel.SimuleosProject;
                  session_id=nothing, labels=String[], script_path="") -> WorkSession

Initialize a work session: resolve, capture metadata, persist, and bind to simos.
"""
function session_init!(simos::_Kernel.SimOs, proj::_Kernel.SimuleosProject;
        session_id = nothing,
        labels::Vector{String} = String[],
        script_path::String = ""
    )
    ws = resolve_session(simos, proj; session_id, labels)

    # Capture metadata if not already present
    if isempty(ws.metadata)
        ws.metadata = _capture_session_metadata(; script_path)
    end
    get(ws.metadata, _Kernel.SESSION_META_GIT_DIRTY_KEY, false) === true &&
        error("Cannot start session: git repository has uncommitted changes.")

    _persist_session!(proj, ws)

    _reset_settings_cache!(ws)
    simos.worksession = ws
    return ws
end

"""
    session_init!(labels, script_path; session_id=nothing) -> WorkSession

Global-state version: uses the current SimOs and project.
"""
function session_init!(labels::Vector{String}, script_path::String; session_id = nothing)
    simos = _Kernel._get_sim()
    proj = _Kernel.sim_project(simos)

    # Guard against reinit with dirty session
    if !isnothing(simos.worksession) && isdirty(simos, simos.worksession)
        error("Cannot reinitialize session: current session has uncommitted captures. Commit or reset first.")
    end

    return session_init!(simos, proj; session_id, labels, script_path)
end

"""
    session_init_from_macro!(labels::Vector, script_path::String)

Entry point from @session_init macro. Validates label types.
"""
function session_init_from_macro!(labels::Vector, script_path::String)
    for l in labels
        l isa AbstractString || error("Session labels must be strings, got: $(typeof(l))")
    end
    session_init!(String[string(l) for l in labels], script_path)
end
