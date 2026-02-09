# Session management — uses current_sim[].recorder instead of separate global

"""
    _get_recorder()

Get the active SessionRecorder from current_sim[].recorder. Errors if none active.
"""
function _get_recorder()::Core.SessionRecorder
    sim = Core._get_sim()
    isnothing(sim.recorder) && error("No active session. Call @session_init first.")
    return sim.recorder
end

"""
    _find_project_root(start_path::String) -> Union{String, Nothing}

Search upward from `start_path` for a `.simuleos/` directory.
Returns the containing directory (the project root), or `nothing` if not found.
"""
function _find_project_root(start_path::String)
    path = abspath(start_path)
    while true
        if isdir(Core.simuleos_dir(path))
            return path
        end
        parent = dirname(path)
        if parent == path  # Reached filesystem root
            return nothing
        end
        path = parent
    end
end

"""
    session_init(label::String, script_path::String)

Internal session creation: locates project root, validates environment,
captures metadata, and initializes the session on `current_sim[].recorder`.
"""
function session_init(label::String, script_path::String)
    # Find project root by searching upward from the script's directory
    start = dirname(abspath(script_path))
    project_root = _find_project_root(start)

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

    # Ensure current_sim is activated for this project
    # Note: we expect the user to have activated the project first.
    sim = Core._get_sim()

    # Clear any previous recorder
    sim.recorder = nothing

    # Capture metadata
    meta = Core._capture_session_metadata(script_path)

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
