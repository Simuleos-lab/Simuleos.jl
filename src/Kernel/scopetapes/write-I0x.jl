# ScopeTapes write primitives (all I0x)
# SimuleosScope variables are materialized at capture time.

const MAX_TAPE_SIZE_BYTES = 200_000_000  # 200 MB threshold for tape file warnings

function _scope_var_to_dict(sv::InlineScopeVariable)::Dict{String, Any}
    out = Dict{String, Any}(
        "src_type" => sv.type_short,
        "src" => sv.level
    )
    out["value"] = _liteify(sv.value)
    return out
end

function _scope_var_to_dict(sv::BlobScopeVariable)::Dict{String, Any}
    out = Dict{String, Any}(
        "src_type" => sv.type_short,
        "src" => sv.level
    )
    out["blob_ref"] = sv.blob_ref.hash
    return out
end

function _scope_var_to_dict(sv::VoidScopeVariable)::Dict{String, Any}
    out = Dict{String, Any}(
        "src_type" => sv.type_short,
        "src" => sv.level
    )
    return out
end

function _scope_metadata_to_dict(metadata::Dict{Symbol, Any})::Dict{String, Any}
    out = Dict{String, Any}()
    for (k, v) in metadata
        out[string(k)] = v
    end
    return out
end

function _scope_to_dict(scope::SimuleosScope)::Dict{String, Any}
    variables = Dict{String, Any}()
    for (name, sv) in scope.variables
        variables[string(name)] = _scope_var_to_dict(sv)
    end

    out = Dict{String, Any}(
        "label" => (isempty(scope.labels) ? "" : scope.labels[1]),
        "variables" => variables
    )

    labels = length(scope.labels) > 1 ? scope.labels[2:end] : String[]
    if !isempty(labels)
        out["labels"] = labels
    end
    if !isempty(scope.metadata)
        out["metadata"] = _scope_metadata_to_dict(scope.metadata)
    end

    return out
end

function _scope_commit_to_dict(commit::ScopeCommit)::Dict{String, Any}
    scopes = Any[_scope_to_dict(scope) for scope in commit.scopes]
    out = Dict{String, Any}(
        "type" => "commit",
        "metadata" => commit.metadata,
        "scopes" => scopes
    )
    if !isempty(commit.commit_label)
        out["commit_label"] = commit.commit_label
    end
    return out
end

function _stage_to_scope_commit(
        commit_label::String,
        stage::ScopeStage,
        meta::Dict{String, Any}
    )::ScopeCommit
    commit_meta = copy(meta)
    commit_meta["timestamp"] = string(Dates.now())
    scopes = SimuleosScope[
        SimuleosScope(copy(scope.labels), copy(scope.variables), copy(scope.metadata))
        for scope in stage.captures
    ]
    return ScopeCommit(
        commit_label,
        commit_meta,
        scopes
    )
end

function _materialize_scope_variables!(
        scope::SimuleosScope,
        blob_refs::Dict{Symbol, BlobRef}
    )::SimuleosScope
    for (name, sv) in scope.variables
        if !(sv isa InlineScopeVariable)
            continue
        end
        if haskey(blob_refs, name)
            scope.variables[name] = BlobScopeVariable(
                sv.level,
                sv.type_short,
                blob_refs[name]
            )
        elseif _is_lite(sv.value)
            scope.variables[name] = InlineScopeVariable(
                sv.level,
                sv.type_short,
                _liteify(sv.value)
            )
        else
            scope.variables[name] = VoidScopeVariable(
                sv.level,
                sv.type_short
            )
        end
    end
    return scope
end
