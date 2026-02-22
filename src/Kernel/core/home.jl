# ============================================================
# home.jl — SimuleosHome (~/.simuleos/) management
# ============================================================

const HOME_REGISTRY_DIRNAME = "registry"

"""Default home directory path."""
_default_home_path() = joinpath(homedir(), SIMULEOS_DIR_NAME)
home_simuleos_default_path()::String = _default_home_path()
_home_settings_path(home_path::String)::String = joinpath(home_path, SETTINGS_JSON)

simuleos_dir(home::SimuleosHome)::String = home.path
registry_path(home::SimuleosHome)::String = joinpath(simuleos_dir(home), HOME_REGISTRY_DIRNAME)
config_path(home::SimuleosHome)::String = joinpath(simuleos_dir(home), "config")
settings_path(home::SimuleosHome)::String = _home_settings_path(simuleos_dir(home))

"""
    home_init!() -> SimuleosHome

Initialize the Simuleos home directory. Creates it if needed.
"""
function home_init!(path::String = _default_home_path())
    path = abspath(path)
    ensure_dir(path)
    ensure_dir(registry_path(SimuleosHome(path)))
    ensure_dir(config_path(SimuleosHome(path)))
    return SimuleosHome(path)
end

function init_home!(home::SimuleosHome)::SimuleosHome
    return home_init!(home.path)
end

function home_init!(simos::SimOs)
    configured = get(simos.bootstrap, "homePath", nothing)
    home_path = if configured isa String && !isempty(strip(configured))
        configured
    else
        _default_home_path()
    end
    simos.home = home_init!(home_path)
    return simos.home
end

"""
    home_settings(home::SimuleosHome) -> Dict{String, Any}

Load settings from `~/.simuleos/settings.json`, or empty Dict if missing.
"""
function home_settings(home::SimuleosHome)
    path = settings_path(home)
    return _read_json_file_or_empty(path)
end
