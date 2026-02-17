# Session management — uses SIMOS[].worksession

function _ensure_string_labels(labels_any::Vector{Any})::Vector{String}
    out = String[]
    for label in labels_any
        label isa AbstractString || error(
            "@session_init labels must be strings. Got $(typeof(label))."
        )
        push!(out, String(label))
    end
    return out
end

"""
    isdirty(simos::Kernel.SimOs, worksession::Kernel.WorkSession)::Bool

I3x — dirty-check hook for active-session replacement policy.
Returns true when there is pending staged session data.
"""
function isdirty(
        simos::Kernel.SimOs,
        worksession::Kernel.WorkSession
    )::Bool
    _ = simos
    cc = worksession.stage.current_scope
    has_pending_scope = !isempty(cc.labels) || !isempty(cc.data)
    has_pending_blob_refs = !isempty(worksession.stage.blob_refs)
    has_pending_captures = !isempty(worksession.stage.captures)
    return has_pending_scope || has_pending_blob_refs || has_pending_captures
end

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

    if !isnothing(simos.worksession) && isdirty(simos, simos.worksession)
        error("Cannot start a new session: current active session is dirty.")
    end

    resolved_session_id = session_id
    if isnothing(resolved_session_id) && !isempty(labels)
        by_label = resolve_session(proj, labels[1])
        resolved_session_id = by_label.session_id
        if isfile(Kernel.session_json_path(proj, resolved_session_id))
            println("Reusing existing session $(resolved_session_id) for first label \"$(labels[1])\".")
        end
    end

    session_init!(simos, proj; session_id=resolved_session_id, labels, script_path)
    return nothing
end

function session_init_from_macro!(
        labels_any::Vector{Any},
        script_path::String
    )::Nothing
    labels = _ensure_string_labels(labels_any)
    session_init!(labels, script_path)
    return nothing
end
