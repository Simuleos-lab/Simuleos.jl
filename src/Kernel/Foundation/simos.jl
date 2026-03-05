# ============================================================
# simos.jl — SimOs global state management
# ============================================================

"""
    _get_simos() -> SimOs

Get the current global SimOs instance. Throws if uninitialized.
"""
_simos_is_ready(sim::SimOs)::Bool = (sim.lifecycle === _SIMOS_LIFECYCLE_READY)

"""
    _get_simos_unsafe() -> SimOs

Get the current global SimOs instance in any lifecycle state. Internal use only.
"""
function _get_simos_unsafe()::SimOs
    sim = SIMOS[]
    if isnothing(sim)
        return _simos_bootstrap_init!()
    end
    return sim
end

function _get_simos()
    sim = _get_simos_unsafe()
    _simos_is_ready(sim) || error("Simuleos not initialized. Call `sim_init!()` first.")
    return sim
end

"""
    _get_simos_or_nothing() -> Union{SimOs, Nothing}

Get the current global SimOs instance only when lifecycle is `:ready`, or `nothing`.
"""
function _get_simos_or_nothing()::Union{Nothing, SimOs}
    sim = SIMOS[]
    isnothing(sim) && return nothing
    _simos_is_ready(sim) || return nothing
    return sim
end

"""
    sim_project() -> SimuleosProject

Get the project from the current global SimOs. Throws if no project.
"""
function sim_project()
    sim = _get_simos()
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
    sim = _get_simos()
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
        SETTING_KEY_HOME_PATH    => home_path,
        SETTING_KEY_PROJECT_ROOT => project_root,
    )
end

function _runtime_settings_from_pairs(kwargs)::Dict{String, Any}
    runtime_settings = Dict{String, Any}()
    for (k, v) in kwargs
        key_raw = string(k)
        key_raw == "bootstrap" &&
            error("sim_init! `bootstrap` was removed. Pass runtime settings as direct keyword args.")
        key = _settings_validate_key(replace(key_raw, "_" => "."))
        haskey(runtime_settings, key) &&
            error("sim_init! duplicate runtime setting key `$(key)`.")
        runtime_settings[key] = v
    end
    return runtime_settings
end

function _runtime_settings_merge_with_sandbox(
        runtime_settings::Dict{String, Any},
        sandbox_runtime_settings::Dict{String, Any},
    )::Dict{String, Any}
    if isempty(sandbox_runtime_settings)
        return runtime_settings
    end

    for key in (SETTING_KEY_HOME_PATH, SETTING_KEY_PROJECT_ROOT)
        haskey(runtime_settings, key) &&
            error("sim_init! sandbox mode sets `$(key)` automatically. Remove that runtime setting.")
    end

    merged = copy(runtime_settings)
    merge!(merged, sandbox_runtime_settings)
    return merged
end

function _runtime_settings_project_root_from_value(value)::String
    if value isa AbstractString
        root = String(value)
        isempty(strip(root)) && error("sim_init! runtime setting `project.root` cannot be empty.")
        return abspath(root)
    elseif value isa Module
        root = pkgdir(value)
        isnothing(root) &&
            error(
                "sim_init! runtime setting `project.root` module `$(value)` has no package directory. " *
                "Use a package module (for example `SomePkg`) or a string path."
            )
        return abspath(String(root))
    end

    error(
        "sim_init! runtime setting `project.root` must be a String path or a Module (resolved via `pkgdir`). " *
        "Got $(typeof(value))."
    )
end

function _runtime_settings_normalize_paths(runtime_settings::Dict{String, Any})::Dict{String, Any}
    normalized = copy(runtime_settings)
    if haskey(normalized, SETTING_KEY_PROJECT_ROOT)
        normalized[SETTING_KEY_PROJECT_ROOT] = _runtime_settings_project_root_from_value(normalized[SETTING_KEY_PROJECT_ROOT])
    end
    return normalized
end

function _bootstrap_cli_source_add!(sim::SimOs)::SimOs
    args = String[string(a) for a in Base.ARGS]
    isempty(args) && return sim
    try
        settings_source_add_args!(sim, args; after = :session)
    catch err
        @warn "Simuleos pre-init CLI settings were skipped due to parse failure." error=string(err)
    end
    return sim
end

function _simos_bootstrap_init!()::SimOs
    sim = SimOs(; lifecycle = _SIMOS_LIFECYCLE_BOOTSTRAP)
    load_settings_stack!(sim)
    _bootstrap_cli_source_add!(sim)
    return set_sim!(sim)
end

function _preinit_runtime_seed_settings()::Dict{String, Any}
    sim = SIMOS[]
    if isnothing(sim) || sim.lifecycle !== _SIMOS_LIFECYCLE_BOOTSTRAP || isnothing(sim.settings_stack)
        return Dict{String, Any}()
    end

    stack = sim.settings_stack::SettingsStack
    seeded = Dict{String, Any}()
    for layer in stack.layers
        layer.name in (:runtime, :script, :session, :cli) || continue
        merge!(seeded, _string_keys(layer.data))
    end
    return seeded
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
    sim_init!(; sandbox=nothing, kwargs...) -> SimOs

Initialize the global Simuleos system.

1. Creates a fresh SimOs
2. Initializes the home directory (~/.simuleos/)
3. Searches for a project (.simuleos/project.json) starting from pwd
4. Loads and merges settings from all layers
"""
function sim_init!(; sandbox = nothing, kwargs...)
    runtime_settings = _preinit_runtime_seed_settings()
    merge!(runtime_settings, _runtime_settings_from_pairs(kwargs))
    sandbox_meta, sandbox_runtime_settings = _sandbox_prepare(sandbox)
    runtime_settings_final = _runtime_settings_merge_with_sandbox(runtime_settings, sandbox_runtime_settings)
    runtime_settings_final = _runtime_settings_normalize_paths(runtime_settings_final)

    simos = SimOs(; lifecycle = _SIMOS_LIFECYCLE_READY, runtime_settings = runtime_settings_final, sandbox = sandbox_meta)

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

Reset the global SimOs to bootstrap pre-init state.
"""
function sim_reset!(; sandbox_cleanup::Symbol = :auto)
    sim = _get_simos_unsafe()
    if !isnothing(sim)
        _simos_close_cached_sqlite_db!(sim)
    end
    if !isnothing(sim) && !isnothing(sim.sandbox) && _sandbox_cleanup_mode(sim.sandbox, sandbox_cleanup)
        _sandbox_cleanup!(sim.sandbox)
    end
    _simos_bootstrap_init!()
    return nothing
end
