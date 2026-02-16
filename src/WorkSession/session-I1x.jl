# Session lifecycle API (all I1x - explicit SimOs and project dependencies)

function _session_labels(labels_any)::Vector{String}
    labels_any isa AbstractVector || return String[]
    return String[string(label) for label in labels_any]
end

"""
    resolve_session(
        simos::Kernel.SimOs,
        proj::Kernel.SimuleosProject;
        session_id::Union{Nothing, Base.UUID} = nothing,
        labels::Vector{String} = String[]
    )::Kernel.WorkSession

I1x — reads disk, no writes

Resolve a work session from explicit dependencies.
- If `session_id` is provided and `.simuleos/sessions/{uuid}/session.json` exists, load labels/meta.
- Otherwise create an in-memory `Kernel.WorkSession` with the requested/new UUID.
- No disk writes, no validations, no side effects on `simos`.
"""
function resolve_session(
        simos::Kernel.SimOs,
        proj::Kernel.SimuleosProject;
        session_id::Union{Nothing, Base.UUID} = nothing,
        labels::Vector{String} = String[]
    )::Kernel.WorkSession
    _ = simos

    resolved_session_id = isnothing(session_id) ? Kernel.UUIDs.uuid4() : session_id
    session_json = Kernel.session_json_path(proj, resolved_session_id)

    if isfile(session_json)
        payload = open(session_json, "r") do io
            Kernel.JSON3.read(io, Dict{String, Any})
        end

        loaded_labels = _session_labels(get(payload, "labels", labels))
        loaded_meta = Dict{String, Any}(get(payload, "meta", Dict{String, Any}()))
        return Kernel.WorkSession(
            session_id = resolved_session_id,
            labels = loaded_labels,
            stage = Kernel.ScopeStage(),
            meta = loaded_meta,
        )
    end

    return Kernel.WorkSession(
        session_id = resolved_session_id,
        labels = labels,
        stage = Kernel.ScopeStage(),
        meta = Dict{String, Any}(),
    )
end

"""
    session_init!(
        simos::Kernel.SimOs,
        proj::Kernel.SimuleosProject;
        session_id::Union{Nothing, Base.UUID} = nothing,
        labels::Vector{String} = String[],
        script_path::String
    )::Nothing

I1x — writes `simos.worksession`; writes disk

Resolve and initialize a work session from explicit dependencies.
- Calls `resolve_session(...)`
- Captures runtime metadata and validates git clean state
- Ensures session/scopetapes directories and `session.json` exist
- Binds the resolved session to `simos.worksession`
"""
function session_init!(
        simos::Kernel.SimOs,
        proj::Kernel.SimuleosProject;
        session_id::Union{Nothing, Base.UUID} = nothing,
        labels::Vector{String} = String[],
        script_path::String
    )::Nothing
    worksession = resolve_session(simos, proj; session_id, labels)
    worksession.meta = _capture_worksession_metadata(script_path)

    if get(worksession.meta, "git_dirty", false) === true
        error("Cannot start session: git repository has uncommitted changes. " *
              "Please commit or stash your changes before recording.")
    end

    session_dir = Kernel._session_dir(proj.simuleos_dir, worksession.session_id)
    scopetapes_dir = Kernel._scopetapes_dir(proj.simuleos_dir, worksession.session_id)
    mkpath(session_dir)
    mkpath(scopetapes_dir)

    session_json = Kernel.session_json_path(proj, worksession.session_id)
    if !isfile(session_json)
        open(session_json, "w") do io
            Kernel.JSON3.pretty(io, Dict(
                "session_id" => string(worksession.session_id),
                "labels" => worksession.labels,
                "meta" => worksession.meta,
            ))
        end
    end

    _reset_settings_cache!(worksession)
    simos.worksession = worksession
    return nothing
end
