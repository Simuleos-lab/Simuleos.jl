# Session lifecycle API (all I1x - explicit SimOs and project dependencies)

function _new_worksession(
        session_id::Base.UUID,
        labels::Vector{String},
        meta::Dict{String, Any}
    )::Kernel.WorkSession
    return Kernel.WorkSession(
        session_id,
        labels,
        Kernel.ScopeStage(
            Kernel.SimuleosScope[],
            Kernel.SimuleosScope(),
            Dict{Symbol, Kernel.BlobRef}()
        ),
        meta,
        Dict{Symbol, Any}[],
        Dict{String, Any}(),
    )
end

function _session_labels(labels_any)::Vector{String}
    labels_any isa AbstractVector || return String[]
    return String[string(label) for label in labels_any]
end

function _session_timestamp(worksession::Kernel.WorkSession)::Dates.DateTime
    raw = get(worksession.meta, "timestamp", nothing)
    raw isa String || return Dates.DateTime(0)
    try
        return Dates.DateTime(raw)
    catch
        return Dates.DateTime(0)
    end
end

function _matches_first_label(worksession::Kernel.WorkSession, label::AbstractString)::Bool
    isempty(worksession.labels) && return false
    return worksession.labels[1] == label
end

"""
    proj_scan_session_files(f::Function, proj::Kernel.SimuleosProject)::Nothing

I1x — project-attached session file scan

Scan all `session.json` files under the project sessions directory and call
`f(raw::Dict{String, Any})` for each file content.
"""
function proj_scan_session_files(
        f::Function,
        proj::Kernel.SimuleosProject
    )::Nothing
    sessions_dir = Kernel._sessions_dir(proj.simuleos_dir)
    isdir(sessions_dir) || return nothing

    for session_name in readdir(sessions_dir)
        session_json = joinpath(sessions_dir, session_name, "session.json")
        isfile(session_json) || continue

        raw = open(session_json, "r") do io
            Kernel.JSON3.read(io, Dict{String, Any})
        end
        f(raw)
    end

    return nothing
end

"""
    parse_session(proj::Kernel.SimuleosProject, raw::Dict{String, Any})::Kernel.WorkSession

I1x — parse raw session file content into a `Kernel.WorkSession` driver.
"""
function parse_session(
        proj::Kernel.SimuleosProject,
        raw::Dict{String, Any}
    )::Kernel.WorkSession
    _ = proj

    haskey(raw, "session_id") || error("Invalid session file: missing `session_id`.")
    session_id_raw = raw["session_id"]
    session_id_raw isa String || error("Invalid session file: `session_id` must be a String.")

    labels = _session_labels(get(raw, "labels", String[]))
    meta = Dict{String, Any}(get(raw, "meta", Dict{String, Any}()))

    return _new_worksession(
        Kernel.UUIDs.UUID(session_id_raw),
        labels,
        meta
    )
end

"""
    resolve_session(proj::Kernel.SimuleosProject, label::String)::Kernel.WorkSession

I1x — project-attached label resolution, no writes.

Resolve by first-label match (`labels[1] == label`). If multiple sessions match,
pick the most recent by session timestamp. If none match, return a new in-memory
session driver.
"""
function resolve_session(
        proj::Kernel.SimuleosProject,
        label::String
    )::Kernel.WorkSession
    stripped_label = strip(label)
    isempty(stripped_label) && error("Session label cannot be empty.")

    matches = Kernel.WorkSession[]
    proj_scan_session_files(proj) do raw
        worksession = parse_session(proj, raw)
        _matches_first_label(worksession, stripped_label) || return
        push!(matches, worksession)
    end

    if isempty(matches)
        return _new_worksession(
            Kernel.UUIDs.uuid4(),
            String[stripped_label],
            Dict{String, Any}()
        )
    end

    sort!(matches; by=ws -> (_session_timestamp(ws), string(ws.session_id)))
    return matches[end]
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
        return parse_session(proj, payload)
    end

    return _new_worksession(
        resolved_session_id,
        labels,
        Dict{String, Any}(),
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
