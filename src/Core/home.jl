# Home directory (~/.simuleos/) is ONLY for global configuration and settings, for the moment.
# Session data (tapes, blobs) is NEVER stored here.
# All session data goes to {project_root}/.simuleos/

_simuleos_dirname() = ".simuleos"

function default_home_path()::String
    joinpath(homedir(), _simuleos_dirname())
end

simuleos_dir(project_root::String)::String = joinpath(project_root, _simuleos_dirname())

project_json_path(project_root::String)::String = joinpath(simuleos_dir(project_root), "project.json")

local_settings_path(project_root::String)::String = joinpath(simuleos_dir(project_root), "settings.json")

global_settings_path(home_path::String)::String = joinpath(home_path, "settings.json")
