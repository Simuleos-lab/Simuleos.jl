# Simuleos home directory management (~/.simuleos)

"""
    init_home(path::String=Core.default_home_path())

Initialize or load the Simuleos home directory.
Creates the directory structure if it doesn't exist.
"""
function init_home(path::String=Core.default_home_path())::Core.SimuleosHome
    if !isdir(path)
        mkpath(path)
        mkpath(joinpath(path, "registry"))
        mkpath(joinpath(path, "config"))
    end
    return Core.SimuleosHome(path=path)
end

"""
    home_path(home::Core.SimuleosHome)

Get the path to the Simuleos home directory.
"""
function home_path(home::Core.SimuleosHome)::String
    home.path
end

"""
    registry_path(home::Core.SimuleosHome)

Get the path to the registry directory.
"""
function registry_path(home::Core.SimuleosHome)::String
    joinpath(home.path, "registry")
end

"""
    config_path(home::Core.SimuleosHome)

Get the path to the config directory.
"""
function config_path(home::Core.SimuleosHome)::String
    joinpath(home.path, "config")
end
