# Home directory (~/.simuleos/) — global configuration and settings only (all I0x — pure path helpers)
# Session data (tapes, blobs) is NEVER stored here.
# All session data goes to {project_root}/.simuleos/

_simuleos_dirname() = ".simuleos"

function default_home_path()::String
    joinpath(homedir(), _simuleos_dirname())
end

# Shared base path helper (used by both home and project paths)
simuleos_dir(project_root::String)::String = joinpath(project_root, _simuleos_dirname())

# Project identity file path (used by sys-init and SIMOS)
project_json_path(project_root::String)::String = joinpath(simuleos_dir(project_root), "project.json")

# Global settings
global_settings_path(home_path::String)::String = joinpath(home_path, "settings.json")
