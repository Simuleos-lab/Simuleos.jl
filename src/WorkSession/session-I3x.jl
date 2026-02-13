# Session management — uses SIMOS[].worksession

"""
    _get_worksession()

I3x — reads `SIMOS[].worksession` via `_get_sim()`

Get the active WorkSession from SIMOS[].worksession. Errors if none active.
"""
function _get_worksession()::Kernel.WorkSession
    sim = Kernel._get_sim()
    isnothing(sim.worksession) && error("No active session. Call @session_init first.")
    return sim.worksession
end

"""
    session_init(label::String, script_path::String)

I3x — reads `SIMOS[]` via `_get_sim()`; writes `SIMOS[].worksession`

Internal session creation: locates project root, validates environment,
captures metadata, and initializes the session on `SIMOS[].worksession`.
"""
function session_init(label::String, script_path::String)
    # Find project root by searching upward from the script's directory
    start = dirname(abspath(script_path))
    project_root = Kernel.find_project_root(start)

    if isnothing(project_root)
        error("No Simuleos project found (no .simuleos/ directory) searching upward from: $start")
    end

    # Guard: home directory must never be used as a session folder
    home_path = Kernel.default_home_path()
    if abspath(project_root) == abspath(dirname(home_path))
        error("Cannot use home directory as a session folder. " *
              "Session data must be stored in a project-local .simuleos/ directory, " *
              "not in ~/.simuleos/.")
    end

    # Ensure SIMOS is activated for this project
    # Note: we expect the user to have activated the project first.
    sim = Kernel._get_sim()

    # Clear any previous work session
    sim.worksession = nothing

    # Capture metadata
    meta = _capture_worksession_metadata(script_path)

    # Error if git repo is dirty
    if get(meta, "git_dirty", false) === true
        error("Cannot start session: git repository has uncommitted changes. " *
              "Please commit or stash your changes before recording.")
    end

    # Create and set the work session on sim
    worksession = Kernel.WorkSession(
        label = label,
        stage = Kernel.Stage(),
        meta = meta
    )
    sim.worksession = worksession

    return worksession
end
