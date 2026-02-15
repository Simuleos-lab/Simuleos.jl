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
    session_init(labels::Vector{String}, script_path::String)

I3x — reads `SIMOS[]` via `_get_sim()`; writes `SIMOS[].worksession`

Internal session creation: locates project root, validates environment,
captures metadata, creates session directory structure, and initializes
the session on `SIMOS[].worksession`.
"""
function session_init(labels::Vector{String}, script_path::String)
    # Find project root by searching upward from the script's directory
    start = dirname(abspath(script_path))
    project_root = Kernel.find_project_root(start)

    if isnothing(project_root)
        error("No Simuleos project found (no .simuleos/ directory) searching upward from: $start")
    end

    # Guard: home directory must never be used as a session folder
    home_path = Kernel.home_simuleos_default_path()
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

    # Generate session identity and create directory structure
    session_id = Kernel.UUIDs.uuid4()
    project = Kernel.sim_project(sim)
    scopetapes_dir = Kernel._scopetapes_dir(project.simuleos_dir, session_id)
    mkpath(scopetapes_dir)

    # Create and set the work session on sim
    worksession = Kernel.WorkSession(
        session_id = session_id,
        labels = labels,
        stage = Kernel.ScopeStage(),
        meta = meta
    )
    sim.worksession = worksession

    return worksession
end
