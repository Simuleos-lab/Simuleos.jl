# ============================================================
# simos.jl — SimOs global state management
# ============================================================

"""
    _get_sim() -> SimOs

Get the current global SimOs instance. Throws if uninitialized.
"""
function _get_sim()
    sim = SIMOS[]
    isnothing(sim) && error("Simuleos not initialized. Call `sim_init!()` first.")
    return sim
end

"""
    _get_sim_or_nothing() -> Union{SimOs, Nothing}

Get the current global SimOs instance, or nothing.
"""
_get_sim_or_nothing() = SIMOS[]

"""
    sim_project() -> SimuleosProject

Get the project from the current global SimOs. Throws if no project.
"""
function sim_project()
    sim = _get_sim()
    isnothing(sim.project) && error("No active project. Ensure sim_init!() found a .simuleos directory.")
    return sim.project
end

"""
    sim_project(simos::SimOs) -> SimuleosProject

Get the project from a SimOs instance.
"""
function sim_project(simos::SimOs)
    isnothing(simos.project) && error("No active project.")
    return simos.project
end

function sim_home()
    sim = _get_sim()
    isnothing(sim.home) && error("No active home.")
    return sim.home
end

function sim_home(simos::SimOs)
    isnothing(simos.home) && error("No active home.")
    return simos.home
end

function set_sim!(new_sim::SimOs)
    SIMOS[] = new_sim
    return new_sim
end

function _simos_close_cached_sqlite_db!(sim::SimOs)
    db = sim.sqlite_db
    if isnothing(db)
        sim.sqlite_db_path = nothing
        return false
    end

    try
        close(db)
    catch
        # Reset should not fail solely because a cached SQLite handle was already closed.
    finally
        sim.sqlite_db = nothing
        sim.sqlite_db_path = nothing
    end
    return true
end

const _SANDBOX_MARKER_FILE = ".simuleos-sandbox.json"

function _sandbox_marker_path(root_path::String)::String
    return joinpath(abspath(root_path), _SANDBOX_MARKER_FILE)
end

function _sandbox_options_dict(sandbox)
    if sandbox isa NamedTuple
        return Dict{String, Any}(string(k) => v for (k, v) in pairs(sandbox))
    elseif sandbox isa AbstractDict
        return Dict{String, Any}(string(k) => v for (k, v) in sandbox)
    end
    error("`sandbox` must be `nothing`, `true`, `false`, a NamedTuple, or a Dict.")
end

function _sandbox_get_bool(opts::Dict{String, Any}, key::String, default::Bool)::Bool
    !haskey(opts, key) && return default
    val = opts[key]
    val isa Bool || error("sandbox option `$(key)` must be Bool, got $(typeof(val))")
    return val
end

function _sandbox_get_string(opts::Dict{String, Any}, key::String, default::String)::String
    !haskey(opts, key) && return default
    val = opts[key]
    val isa AbstractString || error("sandbox option `$(key)` must be String, got $(typeof(val))")
    s = String(val)
    isempty(strip(s)) && error("sandbox option `$(key)` cannot be empty.")
    return s
end

function _sandbox_write_marker!(sb::SimuleosSandbox)
    _write_json_file(_sandbox_marker_path(sb.root_path), Dict(
        "kind" => "simuleos-sandbox-v1",
        "origin" => String(sb.origin),
        "root_path" => sb.root_path,
        "home_path" => sb.home_path,
        "project_root" => sb.project_root,
        "cleanup_on_reset" => sb.cleanup_on_reset,
        "created_at" => string(Dates.now()),
    ))
    return sb
end

function _sandbox_prepare(sandbox)::Tuple{Union{Nothing, SimuleosSandbox}, Dict{String, Any}}
    sandbox === nothing && return (nothing, Dict{String, Any}())
    sandbox === false && return (nothing, Dict{String, Any}())

    local opts::Dict{String, Any}
    local origin::Symbol
    if sandbox === true
        opts = Dict{String, Any}(
            "root" => mktempdir(),
            "cleanup_on_reset" => true,
            "clean_on_init" => false,
            "home_subdir" => "home",
            "project_subdir" => "proj",
        )
        origin = :ephemeral
    else
        opts = _sandbox_options_dict(sandbox)
        origin = :explicit
    end

    haskey(opts, "root") || error("sandbox config requires `root`.")
    root_path = abspath(_sandbox_get_string(opts, "root", ""))
    home_subdir = _sandbox_get_string(opts, "home_subdir", "home")
    project_subdir = _sandbox_get_string(opts, "project_subdir", "proj")
    clean_on_init = _sandbox_get_bool(opts, "clean_on_init", false)
    cleanup_on_reset = _sandbox_get_bool(opts, "cleanup_on_reset", false)

    if clean_on_init && isdir(root_path)
        rm(root_path; recursive = true, force = true)
    end

    ensure_dir(root_path)
    home_path = joinpath(root_path, home_subdir)
    project_root = joinpath(root_path, project_subdir)
    ensure_dir(home_path)
    ensure_dir(project_root)

    sb = SimuleosSandbox(root_path, home_path, project_root, cleanup_on_reset, origin)
    _sandbox_write_marker!(sb)

    return sb, Dict{String, Any}(
        "home.path" => home_path,
        "project.root" => project_root,
    )
end

function _bootstrap_merge_with_sandbox(
        bootstrap::Dict{String, Any},
        sandbox_bootstrap::Dict{String, Any},
    )::Dict{String, Any}
    if isempty(sandbox_bootstrap)
        return bootstrap
    end

    for key in ("home.path", "project.root")
        haskey(bootstrap, key) &&
            error("sim_init! sandbox mode sets `$(key)` automatically. Remove it from `bootstrap`.")
    end

    merged = copy(bootstrap)
    merge!(merged, sandbox_bootstrap)
    return merged
end

function _sandbox_cleanup_mode(sb::SimuleosSandbox, sandbox_cleanup::Symbol)::Bool
    sandbox_cleanup in (:auto, :keep, :delete) ||
        error("sim_reset! `sandbox_cleanup` must be one of `:auto`, `:keep`, `:delete`.")
    sandbox_cleanup === :auto && return sb.cleanup_on_reset
    sandbox_cleanup === :keep && return false
    return true
end

function _sandbox_safe_delete_root(root_path::String)::Bool
    root = abspath(root_path)
    isempty(strip(root)) && return false
    dirname(root) == root && return false
    root == abspath(homedir()) && return false
    return true
end

function _sandbox_cleanup!(sb::SimuleosSandbox)
    root = abspath(sb.root_path)
    isdir(root) || return nothing

    marker_path = _sandbox_marker_path(root)
    isfile(marker_path) || error("Refusing to delete sandbox root without marker file: $(root)")
    _sandbox_safe_delete_root(root) || error("Refusing to delete unsafe sandbox root: $(root)")

    rm(root; recursive = true, force = true)
    return nothing
end

"""
    sim_init!(; bootstrap::Dict = Dict{String, Any}(), sandbox=nothing) -> SimOs

Initialize the global Simuleos system.

1. Creates a fresh SimOs
2. Initializes the home directory (~/.simuleos/)
3. Searches for a project (.simuleos/project.json) starting from pwd
4. Loads and merges settings from all layers
"""
function sim_init!(; bootstrap::Dict = Dict{String, Any}(), sandbox = nothing)
    bootstrap_norm = Dict{String, Any}(string(k) => v for (k, v) in bootstrap)
    sandbox_meta, sandbox_bootstrap = _sandbox_prepare(sandbox)
    bootstrap_final = _bootstrap_merge_with_sandbox(bootstrap_norm, sandbox_bootstrap)

    simos = SimOs(; bootstrap = bootstrap_final, sandbox = sandbox_meta)

    # Phase 1: Home
    home_init!(simos)

    # Phase 2: Project
    proj_init!(simos)

    # Phase 3: Settings
    load_settings_stack!(simos)

    # Phase 4: Git handler
    if !isnothing(simos.project)
        simos.project.git_handler = _git_handler_for(simos.project.root_path)
    end

    # Activate
    return set_sim!(simos)
end

"""
    sim_reset!(; sandbox_cleanup=:auto)

Reset the global SimOs to nothing.
"""
function sim_reset!(; sandbox_cleanup::Symbol = :auto)
    sim = SIMOS[]
    if !isnothing(sim)
        _simos_close_cached_sqlite_db!(sim)
    end
    if !isnothing(sim) && !isnothing(sim.sandbox) && _sandbox_cleanup_mode(sim.sandbox, sandbox_cleanup)
        _sandbox_cleanup!(sim.sandbox)
    end
    SIMOS[] = nothing
    return nothing
end
