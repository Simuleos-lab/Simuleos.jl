# System initialization (I2x - explicit SimOs integration)

"""
    reset!(simos::SimOs)

I2x — writes simos runtime fields

Reset runtime subsystem references on `simos`.
"""
function reset!(simos::SimOs)
    simos.worksession = nothing
    simos.project = nothing
    simos.home = nothing
    simos.ux = nothing
    return nothing
end

"""
    nuke!(simos::SimOs)

I2x — reads simos.home/simos.project; writes disk

Delete active home and project `.simuleos` folders.
"""
function nuke!(simos::SimOs)
    rm(simuleos_dir(sim_home(simos)); recursive=true, force=true)
    rm(simuleos_dir(sim_project(simos)); recursive=true, force=true)
    return nothing
end

"""
    sim_init!(simos::SimOs; bootstrap::Dict{String, Any} = Dict{String, Any}())

I2x — writes simos.ux, simos.home, simos.project

Boot the SimOs instance through all initialization phases.
Lazy — each phase is skipped if its field is already set.
- Phase 0: UXLayer (settings become available)
- Phase 1: Home (~/.simuleos/)
- Phase 2: Project (.simuleos/)
- Phase 3: UXLayer settings refresh (:local + :home sources)
"""
function sim_init!(
        simos::SimOs;
        bootstrap::Dict{String, Any} = Dict{String, Any}(), 
        _nukeFirst::Bool = false # dev/testing option 
    )

    # Phase 0: init uxlayer (skip if already set)
    if isnothing(simos.ux)
        simos.ux = uxlayer_init(bootstrap)
    end
    # NOTE: from now on, we can use settings(simos, key, default) during init.

    # Phase 1: init home (skip if already set)
    isnothing(simos.home) && home_init!(simos)

    # Phase 2: init project (skip if already set)
    isnothing(simos.project) && proj_init!(simos)

    # nuke
    if _nukeFirst === true
        nuke!(simos)
        reset!(simos)

        # Restart init with nuking done.
        return sim_init!(simos; bootstrap, _nukeFirst=false) 
    end

    # Phase 3: load project-local and home-global settings into UXLayer
    uxlayer_load_settings!(simos)

    return nothing
end
