# JSONL tape I/O for recording simulation sessions

using JSON3
using Dates

function _scope_variable_to_dict(sv::ScopeVariable)::Dict{String, Any}
    d = Dict{String, Any}(
        "name" => sv.name,
        "type" => sv.type,
        "src" => string(sv.src)  # :local or :global
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
    d = Dict{String, Any}(
        "label" => scope.label,
        "timestamp" => string(scope.timestamp),
        "variables" => Dict(
            name => _scope_variable_to_dict(sv)
            for (name, sv) in scope.variables
        )
    )

    # Add context labels if any
    if !isempty(scope.context_labels)
        d["context_labels"] = scope.context_labels
    end

    # Add context data if any
    if !isempty(scope.context_data)
        d["context_data"] = Dict(string(k) => v for (k, v) in scope.context_data)
    end

    return d
end

function _create_commit_record(session::Session, commit_label::String="")::Dict{String, Any}
    record = Dict{String, Any}(
        "type" => "commit",
        "session_label" => session.label,
        "metadata" => session.meta,
        "scopes" => [_scope_to_dict(s) for s in session.stage.scopes],
        "blob_refs" => collect(session.stage.blob_refs)
    )

    # Add commit label if provided
    if !isempty(commit_label)
        record["commit_label"] = commit_label
    end

    return record
end

function _append_to_tape(session::Session, record::Dict{String, Any})
    # Use session-specific directory
    safe_label = replace(session.label, r"[^\w\-]" => "_")
    session_dir = joinpath(session.root_dir, "sessions", safe_label)
    tapes_dir = joinpath(session_dir, "tapes")
    mkpath(tapes_dir)

    tape_path = joinpath(tapes_dir, "context.tape.jsonl")

    open(tape_path, "a") do io
        JSON3.write(io, record)
        println(io)
    end
end
