# ScopeTapes write primitives (all I0x)
# Blob/lite classification happens while building commit Dict payloads.

const MAX_TAPE_SIZE_BYTES = 200_000_000  # 200 MB threshold for tape file warnings

function _get_type_string(val)::String
    first(string(typeof(val)), 25)
end

function _compute_blob_refs(ctx::CaptureContext, storage::BlobStorage)::Dict{Symbol, String}
    refs = Dict{Symbol, String}()
    for (name, sv) in ctx.scope.variables
        if name in ctx.blob_set
            ref = blob_write(storage, sv.val, sv.val)
            refs[name] = ref.hash
        end
    end
    refs
end

function _scope_var_to_dict(
        name::Symbol, sv::ScopeVariable,
        blob_refs::Dict{Symbol, String}
    )::Dict{String, Any}
    src_type = _get_type_string(sv.val)
    out = Dict{String, Any}(
        "src_type" => src_type,
        "src" => sv.src
    )

    if haskey(blob_refs, name)
        out["blob_ref"] = blob_refs[name]
    elseif _is_lite(sv.val)
        out["value"] = _liteify(sv.val)
    end

    return out
end

function _capture_to_scope_dict(
        ctx::CaptureContext,
        blob_refs::Dict{Symbol, String}
    )::Dict{String, Any}
    scope = ctx.scope
    variables = Dict{String, Any}()
    for (name, sv) in scope.variables
        variables[string(name)] = _scope_var_to_dict(name, sv, blob_refs)
    end

    out = Dict{String, Any}(
        "label" => (isempty(scope.labels) ? "" : scope.labels[1]),
        "timestamp" => ctx.timestamp,
        "variables" => variables
    )

    labels = length(scope.labels) > 1 ? scope.labels[2:end] : String[]
    if !isempty(labels)
        out["labels"] = labels
    end
    if !isempty(ctx.data)
        out["data"] = ctx.data
    end

    return out
end

function _stage_to_commit_dict(
        commit_label::String,
        stage::ScopeStage,
        meta::Dict{String, Any},
        storage::BlobStorage
    )::Dict{String, Any}
    capture_blob_refs = Dict{Symbol, String}[]
    all_blob_refs = Set{String}()
    for ctx in stage.captures
        refs = _compute_blob_refs(ctx, storage)
        push!(capture_blob_refs, refs)
        union!(all_blob_refs, values(refs))
    end

    scopes = Any[
        _capture_to_scope_dict(ctx, capture_blob_refs[i])
        for (i, ctx) in enumerate(stage.captures)
    ]

    out = Dict{String, Any}(
        "type" => "commit",
        "metadata" => meta,
        "scopes" => scopes,
        "blob_refs" => sort!(collect(all_blob_refs))
    )
    if !isempty(commit_label)
        out["commit_label"] = commit_label
    end
    return out
end
