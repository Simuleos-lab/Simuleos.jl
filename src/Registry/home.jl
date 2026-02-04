# Simuleos home directory management (~/.simuleos)
# Stub implementation - to be expanded

using ..Core: SimuleosHome

"""
    init_home(path::String=joinpath(homedir(), ".simuleos"))

Initialize or load the Simuleos home directory.
Creates the directory structure if it doesn't exist.
"""
function init_home(path::String=joinpath(homedir(), ".simuleos"))::SimuleosHome
    if !isdir(path)
        mkpath(path)
        mkpath(joinpath(path, "registry"))
        mkpath(joinpath(path, "config"))
    end
    return SimuleosHome(path=path)
end

"""
    home_path(home::SimuleosHome)

Get the path to the Simuleos home directory.
"""
function home_path(home::SimuleosHome)::String
    home.path
end

"""
    registry_path(home::SimuleosHome)

Get the path to the registry directory.
"""
function registry_path(home::SimuleosHome)::String
    joinpath(home.path, "registry")
end

"""
    config_path(home::SimuleosHome)

Get the path to the config directory.
"""
function config_path(home::SimuleosHome)::String
    joinpath(home.path, "config")
end
