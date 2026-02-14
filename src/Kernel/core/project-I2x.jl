# Project/home methods for SimOs (all I2x - explicit SimOs integration)

simuleos_dir(sim::SimOs)::String = simuleos_dir(sim_project(sim))
project_json_path(sim::SimOs)::String = project_json_path(sim_project(sim))
proj_settings_path(sim::SimOs)::String = proj_settings_path(sim_project(sim))
tape_path(sim::SimOs)::String = tape_path(sim_project(sim))

home_settings_path(sim::SimOs)::String = home_settings_path(sim.home_path)
