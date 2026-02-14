# Project/home driver methods (all I1x - explicit subsystem objects)

simuleos_dir(project::Project)::String = simuleos_dir(project.root_path)
project_json_path(project::Project)::String = project_json_path(project.root_path)
proj_settings_path(project::Project)::String = proj_settings_path(project.root_path)
tape_path(project::Project)::String = tape_path(project.simuleos_dir)

blob_path(project::Project, sha1::String)::String = blob_path(project.blobstorage, sha1)

function init_home(home::SimuleosHome)::SimuleosHome
    hpath = home_path(home)
    mkpath(hpath)
    mkpath(registry_path(home))
    return home
end

home_path(home::SimuleosHome)::String = home.path
registry_path(home::SimuleosHome)::String = joinpath(home.path, HOME_REGISTRY_DIRNAME)
config_path(home::SimuleosHome)::String = joinpath(home.path, "config")
home_settings_path(home::SimuleosHome)::String = home_settings_path(home_path(home))
