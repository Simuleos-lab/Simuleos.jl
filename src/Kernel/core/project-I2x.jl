# Project/home methods for SimOs (all I2x - explicit SimOs integration)

proj_json_path(sim::SimOs)::String = proj_json_path(sim_project(sim))
proj_settings_path(sim::SimOs)::String = settings_path(sim_project(sim))

home_settings_path(sim::SimOs)::String = settings_path(sim_home(sim))


