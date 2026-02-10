# Simuleos home directory management (~/.simuleos)

const REGISTRY_DIRNAME = "registry"

"""
    init_home(path::String=Kernel.default_home_path())

I0x — pure directory initialization (no SimOs integration)

Initialize or load the Simuleos home directory.
Creates the directory structure if it doesn't exist.
"""
function init_home(path::String=Kernel.default_home_path())::Kernel.SimuleosHome
    if !isdir(path)
        mkpath(path)
        mkpath(joinpath(path, REGISTRY_DIRNAME))
    end
    return Kernel.SimuleosHome(path=path)
end

"""
    home_path(home::Kernel.SimuleosHome)

I0x — pure accessor

Get the path to the Simuleos home directory.
"""
function home_path(home::Kernel.SimuleosHome)::String
    home.path
end

"""
    registry_path(home::Kernel.SimuleosHome)

I0x — pure accessor

Get the path to the registry directory.
"""
function registry_path(home::Kernel.SimuleosHome)::String
    joinpath(home.path, REGISTRY_DIRNAME)
end

"""
    config_path(home::Kernel.SimuleosHome)

I0x — pure accessor

Get the path to the config directory.
"""
function config_path(home::Kernel.SimuleosHome)::String
    joinpath(home.path, "config")
end
