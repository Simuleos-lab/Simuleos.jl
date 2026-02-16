# Session management — uses SIMOS[].worksession

"""
    _get_worksession()

I3x — reads `SIMOS[].worksession` via `_get_sim()`

Get the active WorkSession from SIMOS[].worksession. Errors if none active.
"""
function _get_worksession()::Kernel.WorkSession
    sim = Kernel._get_sim()
    isnothing(sim.worksession) && error("No active session. Call @session_init first.")
    return sim.worksession
end

"""
    session_init!(
        labels::Vector{String},
        script_path::String;
        session_id::Union{Nothing, Base.UUID} = nothing
    )::Nothing

I3x — reads `SIMOS[]` via `_get_sim()`; writes `SIMOS[].worksession`

Global WorkSession initializer used by `@session_init`.
Resolves explicit dependencies from the active `SIMOS[]` and delegates to
`session_init!(simos, proj; ...)`.
"""
function session_init!(
        labels::Vector{String},
        script_path::String;
        session_id::Union{Nothing, Base.UUID} = nothing
    )::Nothing
    simos = Kernel._get_sim()
    proj = Kernel.sim_project(simos)
    session_init!(simos, proj; session_id, labels, script_path)
    return nothing
end
