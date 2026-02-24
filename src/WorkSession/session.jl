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
        return _read_persisted_session(proj, sid)
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

    return _read_persisted_session(proj, sid)
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

function _read_persisted_session(proj::_Kernel.SimuleosProject, session_id):: _Kernel.WorkSession
    session_json = _Kernel.session_json_path(proj, session_id)
    return parse_session(proj, _Kernel._read_json_file(session_json))
end

"""
    _persist_session!(proj, ws::_Kernel.WorkSession)

Write session.json to disk.
"""
function _persist_session!(proj::_Kernel.SimuleosProject, ws::_Kernel.WorkSession)
    sjson = _Kernel.session_json_path(proj, ws.session_id)
    # `context_hash_reg` is intentionally runtime-only and is not persisted in session.json.
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
    _ = simos
    return !isempty(ws.stage.captures) || !isempty(ws.pending_commits)
end

function _primary_session_label(ws::_Kernel.WorkSession)::Union{Nothing, String}
    isempty(ws.labels) && return nothing
    return ws.labels[1]
end

function _session_init_callsite(ws::_Kernel.WorkSession)::Union{Nothing, String}
    file = get(ws.metadata, _Kernel.SESSION_META_INIT_FILE_KEY, "")
    file isa AbstractString || return nothing
    file_str = String(file)
    isempty(file_str) && return nothing

    line = get(ws.metadata, _Kernel.SESSION_META_INIT_LINE_KEY, nothing)
    if line isa Integer && Int(line) > 0
        return string(file_str, ":", Int(line))
    end
    return file_str
end

function _warn_if_switching_unfinalized_session!(current_ws::_Kernel.WorkSession, next_labels::Vector{String})
    current_ws.is_finalized && return nothing
    isempty(next_labels) && return nothing

    prev_label = _primary_session_label(current_ws)
    isnothing(prev_label) && return nothing

    next_label = _Kernel._normalize_session_label(next_labels[1])
    prev_label == next_label && return nothing

    prev_init = _session_init_callsite(current_ws)
    if isnothing(prev_init)
        @warn "Switching to a new session without finalizing the previous one." previous_session=prev_label next_session=next_label
        return nothing
    end

    @warn "Switching to a new session without finalizing the previous one. Previous session `$(prev_label)` was initialized at $(prev_init)." previous_session=prev_label next_session=next_label previous_session_init=prev_init
    return nothing
end

"""
    session_init!(simos::_Kernel.SimOs, proj::_Kernel.SimuleosProject;
                  session_id=nothing, labels=String[], script_path="") -> WorkSession

Initialize a work session: resolve, capture metadata, persist, and bind to simos.
"""
function session_init!(simos::_Kernel.SimOs, proj::_Kernel.SimuleosProject;
        session_id = nothing,
        labels::Vector{String} = String[],
        script_path::String = "",
        init_file::String = "",
        init_line::Int = 0,
    )
    ws = resolve_session(simos, proj; session_id, labels)

    # Capture metadata if not already present
    if isempty(ws.metadata)
        ws.metadata = _capture_session_metadata(; script_path)
        _set_session_init_callsite!(ws.metadata; init_file, init_line)
    end
    get(ws.metadata, _Kernel.SESSION_META_GIT_DIRTY_KEY, false) === true &&
        error("Cannot start session: git repository has uncommitted changes.")

    _persist_session!(proj, ws)

    _reset_session_settings!(ws)
    simos.worksession = ws
    return ws
end

"""
    session_init!(labels, script_path; session_id=nothing) -> WorkSession

Global-state version: uses the current SimOs and project.
"""
function session_init!(labels::Vector{String}, script_path::String;
        session_id = nothing,
        init_file::String = "",
        init_line::Int = 0,
    )
    simos = _Kernel._get_sim()
    proj = _Kernel.sim_project(simos)

    # Guard against reinit with dirty session
    if !isnothing(simos.worksession) && isdirty(simos, simos.worksession)
        error("Cannot reinitialize session: current session has uncommitted captures. Commit or reset first.")
    end
    if !isnothing(simos.worksession)
        _warn_if_switching_unfinalized_session!(simos.worksession, labels)
    end

    return session_init!(simos, proj;
        session_id,
        labels,
        script_path,
        init_file,
        init_line,
    )
end

function _macro_labels_to_strings(labels::Vector)::Vector{String}
    for l in labels
        l isa AbstractString || error("Session labels must be strings, got: $(typeof(l))")
    end
    return String[string(l) for l in labels]
end

function _macro_ensure_engine_initialized!(;
        bootstrap = nothing,
        sandbox = nothing,
        reinit::Bool = false,
        sandbox_cleanup::Symbol = :auto,
    )
    sim = _Kernel._get_sim_or_nothing()

    if reinit && !isnothing(sim)
        _Kernel.sim_reset!(; sandbox_cleanup = sandbox_cleanup)
        sim = nothing
    end

    has_engine_options = reinit || !isnothing(bootstrap) || !isnothing(sandbox)

    if isnothing(sim)
        if isnothing(bootstrap)
            _Kernel.sim_init!(; sandbox = sandbox)
        else
            bootstrap isa Dict || error("@simos system.init `bootstrap` option must be a Dict.")
            _Kernel.sim_init!(; bootstrap = bootstrap, sandbox = sandbox)
        end
        return nothing
    end

    if has_engine_options
        error("Simuleos is already initialized. Use `reinit=true` with `@simos system.init(...)` to reset/reconfigure the engine.")
    end

    return nothing
end

"""
    engine_init_from_macro!(script_path::String, src_line::Int; ...) -> SimOs

Entry point from `@simos system.init(...)`. Initializes or reinitializes the Simuleos
engine only. Does not start a recording session.
"""
function engine_init_from_macro!(script_path::String, src_line::Int;
        bootstrap = nothing,
        sandbox = nothing,
        reinit::Bool = false,
        sandbox_cleanup::Symbol = :auto,
    )
    _ = script_path
    _ = src_line
    _macro_ensure_engine_initialized!(;
        bootstrap,
        sandbox,
        reinit,
        sandbox_cleanup,
    )
    return _Kernel._get_sim()
end

"""
    session_init_from_macro!(labels::Vector, script_path::String, src_line::Int) -> WorkSession

Entry point from `@simos session.init(...)`. Starts or switches the active
recording session using the already-initialized engine.
"""
function session_init_from_macro!(labels::Vector, script_path::String, src_line::Int)
    labels_s = _macro_labels_to_strings(labels)
    return session_init!(labels_s, script_path;
        init_file = script_path,
        init_line = src_line,
    )
end
