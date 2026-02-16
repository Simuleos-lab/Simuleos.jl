# System initialization (I2x - explicit SimOs integration)

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
        bootstrap::Dict{String, Any} = Dict{String, Any}()
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

    # Phase 3: load project-local and home-global settings into UXLayer
    uxlayer_load_settings!(simos)

    return nothing
end
