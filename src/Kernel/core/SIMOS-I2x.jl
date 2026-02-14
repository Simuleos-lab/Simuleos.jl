# SIMOS explicit-object methods (all I2x - explicit SimOs integration)

"""
    sim_project(sim::SimOs)

I2x - reads `sim.project`

Get the active Project for an explicit SimOs instance.
"""
function sim_project(sim::SimOs)::Project
    isnothing(sim.project) && error("No project activated. Use Simuleos.sim_activate(proj_path) first.")
    return sim.project
end

"""
    sim_home(sim::SimOs)

I2x - reads `sim.home`

Get the active SimuleosHome for an explicit SimOs instance.
"""
function sim_home(sim::SimOs)::SimuleosHome
    isnothing(sim.home) && error("No home activated. Use Simuleos.sim_activate(proj_path) first.")
    return sim.home
end
