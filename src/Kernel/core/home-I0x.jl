# Home directory (~/.simuleos/) — global configuration and settings only (all I0x — pure path helpers)

const HOME_REGISTRY_DIRNAME = "registry"

function home_simuleos_default_path()::String
    joinpath(homedir(), SIMULEOS_DIR_NAME)
end

# Home settings path (bootstrap SSOT)
_home_settings_path(home_path::String)::String = joinpath(home_path, "settings.json")

