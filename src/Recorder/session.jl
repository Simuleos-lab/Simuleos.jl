# Session management — uses SIMOS[].recorder instead of separate global

"""
    _get_recorder()

I3x — reads `SIMOS[].recorder` via `_get_sim()`

Get the active SessionRecorder from SIMOS[].recorder. Errors if none active.
"""
function _get_recorder()::Core.SessionRecorder
    sim = Core._get_sim()
    isnothing(sim.recorder) && error("No active session. Call @session_init first.")
    return sim.recorder
end

"""
    session_init(label::String, script_path::String)

I3x — reads `SIMOS[]` via `_get_sim()`; writes `SIMOS[].recorder`

Internal session creation: locates project root, validates environment,
captures metadata, and initializes the session on `SIMOS[].recorder`.
"""
function session_init(label::String, script_path::String)
    # Find project root by searching upward from the script's directory
    start = dirname(abspath(script_path))
    project_root = Core.find_project_root(start)

    if isnothing(project_root)
        error("No Simuleos project found (no .simuleos/ directory) searching upward from: $start")
    end

    # Guard: home directory must never be used as a session folder
    home_path = Core.default_home_path()
    if abspath(project_root) == abspath(dirname(home_path))
        error("Cannot use home directory as a session folder. " *
              "Session data must be stored in a project-local .simuleos/ directory, " *
              "not in ~/.simuleos/.")
    end

    # Ensure SIMOS is activated for this project
    # Note: we expect the user to have activated the project first.
    sim = Core._get_sim()

    # Clear any previous recorder
    sim.recorder = nothing

    # Capture metadata
    meta = _capture_recorder_session_metadata(script_path)

    # Error if git repo is dirty
    if get(meta, "git_dirty", false) === true
        error("Cannot start session: git repository has uncommitted changes. " *
              "Please commit or stash your changes before recording.")
    end

    # Create and set the recorder on sim
    recorder = Core.SessionRecorder(
        label = label,
        stage = Core.Stage(),
        meta = meta
    )
    sim.recorder = recorder

    return recorder
end

# ==================================
# Metadata Capture
# ==================================

"""
    _capture_recorder_session_metadata(script_path, git_handler=nothing)

I0x — pure metadata capture (no SimOs integration)

Capture metadata for a recorder session: timestamp, Julia version, hostname, git info.
"""
function _capture_recorder_session_metadata(
        script_path,
        git_handler = Core.GitHandler(dirname(script_path))
    )::Dict{String,Any}
    meta = Dict{String,Any}()

    # Timestamp
    meta["timestamp"] = string(Dates.now())

    # Julia version
    meta["julia_version"] = string(VERSION)

    # Hostname
    meta["hostname"] = gethostname()

    # Script path
    meta["script_path"] = script_path

    # Git information
    if !isnothing(git_handler)
        try
            meta["git_commit"] = Core.git_hash(git_handler)
            meta["git_dirty"] = Core.git_dirty(git_handler)
        catch
            meta["git_commit"] = nothing
            meta["git_dirty"] = nothing
        end
    end

    return meta
end
