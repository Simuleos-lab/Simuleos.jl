# Home driver methods (all I1x - explicit subsystem objects)

simuleos_dir(home::SimuleosHome)::String = home.path
registry_path(home::SimuleosHome)::String = joinpath(simuleos_dir(home), HOME_REGISTRY_DIRNAME)
config_path(home::SimuleosHome)::String = joinpath(simuleos_dir(home), "config")
settings_path(home::SimuleosHome)::String = _home_settings_path(simuleos_dir(home))

function init_home!(home::SimuleosHome)::SimuleosHome
    hpath = simuleos_dir(home)
    mkpath(hpath)
    mkpath(registry_path(home))
    return home
end
