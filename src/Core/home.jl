# Home directory (~/.simuleos/) is ONLY for global configuration and settings, for the moment.
# Session data (tapes, blobs) is NEVER stored here.
# All session data goes to {project_root}/.simuleos/

function default_home_path()::String
    joinpath(homedir(), ".simuleos")
end