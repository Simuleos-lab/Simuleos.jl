# JSONL tape I/O for recording simulation sessions

using JSON3
using Dates

function _scope_variable_to_dict(sv::ScopeVariable)::Dict{String, Any}
    d = Dict{String, Any}(
        "name" => sv.name,
        "type" => sv.type
    )
    if !isnothing(sv.value)
        d["value"] = sv.value
    end
    if !isnothing(sv.blob_ref)
        d["blob_ref"] = sv.blob_ref
    end
    return d
end

function _scope_to_dict(scope::Scope)::Dict{String, Any}
    return Dict{String, Any}(
        "label" => scope.label,
        "timestamp" => string(scope.timestamp),
        "variables" => Dict(
            name => _scope_variable_to_dict(sv)
            for (name, sv) in scope.variables
        )
    )
end

function _create_commit_record(session::Session)::Dict{String, Any}
    return Dict{String, Any}(
        "type" => "commit",
        "session_label" => session.label,
        "metadata" => session.meta,
        "scopes" => [_scope_to_dict(s) for s in session.stage.scopes],
        "blob_refs" => collect(session.stage.blob_refs)
    )
end

function _append_to_tape(session::Session, record::Dict{String, Any})
    tapes_dir = joinpath(session.root_dir, "tapes")
    mkpath(tapes_dir)

    # Sanitize label for filename
    safe_label = replace(session.label, r"[^\w\-]" => "_")
    tape_path = joinpath(tapes_dir, "$(safe_label).jsonl")

    open(tape_path, "a") do io
        JSON3.write(io, record)
        println(io)
    end
end
