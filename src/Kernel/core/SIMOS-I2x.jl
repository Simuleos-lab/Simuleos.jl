# SIMOS explicit-object methods (all I2x - explicit SimOs integration)

"""
    sim_project(sim::SimOs)

I2x - reads `sim.project`

Get the active SimuleosProject for an explicit SimOs instance.
"""
function sim_project(sim::SimOs)::SimuleosProject
    isnothing(sim.project) && error("No project initialized. Call Simuleos.sim_init!() first.")
    return sim.project
end

"""
    sim_home(sim::SimOs)

I2x - reads `sim.home`

Get the active SimuleosHome for an explicit SimOs instance.
"""
function sim_home(sim::SimOs)::SimuleosHome
    isnothing(sim.home) && error("No home initialized. Call Simuleos.sim_init!() first.")
    return sim.home
end

function _simos_onoff(value)::String
    return isnothing(value) ? "off" : "on"
end

function _simos_phase(sim::SimOs)::String
    if isnothing(sim.ux)
        return "cold"
    elseif isnothing(sim.home) || isnothing(sim.project)
        return "booting"
    else
        return "ready"
    end
end

function _simos_project_root(sim::SimOs)
    if sim.project isa SimuleosProject
        return sim.project.root_path
    end
    return nothing
end

function _simos_home_path(sim::SimOs)
    if sim.home isa SimuleosHome
        return sim.home.path
    end
    return nothing
end

function _simos_worksession_id(sim::SimOs)
    ws = sim.worksession
    if isnothing(ws)
        return nothing
    end
    if hasproperty(ws, :session_id)
        return getproperty(ws, :session_id)
    end
    return nothing
end

"""
    Base.show(io::IO, sim::SimOs)

Compact one-line status view for SimOs.
"""
function Base.show(io::IO, sim::SimOs)
    print(
        io,
        "SimOs(",
        "phase=", _simos_phase(sim),
        ", project=", _simos_onoff(sim.project),
        ", home=", _simos_onoff(sim.home),
        ", ux=", _simos_onoff(sim.ux),
        ", worksession=", _simos_onoff(sim.worksession),
        ", bootstrap=", length(sim.bootstrap), " keys",
        ")",
    )
end

"""
    Base.show(io::IO, ::MIME"text/plain", sim::SimOs)

Rich text/plain view with subsystem state and key runtime paths.
"""
function Base.show(io::IO, ::MIME"text/plain", sim::SimOs)
    compact = get(io, :compact, false)
    compact && return Base.show(io, sim)

    project_root = _simos_project_root(sim)
    home_path = _simos_home_path(sim)
    ws_id = _simos_worksession_id(sim)

    println(io, "SimOs Runtime [", _simos_phase(sim), "]")
    println(io, "  bootstrap keys : ", length(sim.bootstrap))
    println(io, "  project        : ", isnothing(project_root) ? "<none>" : project_root)
    println(io, "  home           : ", isnothing(home_path) ? "<none>" : home_path)
    println(io, "  ux             : ", _simos_onoff(sim.ux))
    println(io, "  worksession    : ", isnothing(ws_id) ? "<none>" : string(ws_id))
    print(io, "  status         : [project=", _simos_onoff(sim.project))
    print(io, " home=", _simos_onoff(sim.home))
    print(io, " ux=", _simos_onoff(sim.ux))
    print(io, " ws=", _simos_onoff(sim.worksession), "]")
end
