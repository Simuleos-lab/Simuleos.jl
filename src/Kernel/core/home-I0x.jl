# Home directory (~/.simuleos/) — global configuration and settings only (all I0x — pure path helpers)
# Session data (tapes, blobs) is NEVER stored here.
# All session data goes to {project_root}/.simuleos/

const HOME_REGISTRY_DIRNAME = "registry"

function simuleos_home_default_path()::String
    joinpath(homedir(), SIMULEOS_DIR_NAME)
end

# Home settings path (bootstrap SSOT)
_home_settings_path(home_path::String)::String = joinpath(home_path, "settings.json")
