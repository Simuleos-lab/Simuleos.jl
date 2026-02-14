# Home driver methods (all I1x - explicit subsystem objects)

home_path(home::SimuleosHome)::String = home.path
registry_path(home::SimuleosHome)::String = joinpath(home.path, HOME_REGISTRY_DIRNAME)
config_path(home::SimuleosHome)::String = joinpath(home.path, "config")
settings_path(home::SimuleosHome)::String = _home_settings_path(home_path(home))

function init_home(home::SimuleosHome)::SimuleosHome
    hpath = home_path(home)
    mkpath(hpath)
    mkpath(registry_path(home))
    return home
end
