# ============================================================
# scopetapes/write.jl — Writing commits to tape
# ============================================================

function _require_scope_class_registration!()::Nothing
    class_require!(_SCOPE_CLASS_ID, _SCOPE_CLASS_VERSION)
    return nothing
end

"""
    _write_json(io::IO, var::InlineScopeVariable)

Serialize an inline variable record.
"""
function _write_json(io::IO, var::InlineScopeVariable)
    print(io, "{\"src_type\":")
    _write_json(io, var.type_short)
    print(io, ",\"src\":")
    _write_json(io, string(var.level))
    print(io, ",\"value\":")
    _write_json(io, var.value)
    print(io, "}")
    return nothing
end

function _write_json(io::IO, var::BlobScopeVariable)
    print(io, "{\"src_type\":")
    _write_json(io, var.type_short)
    print(io, ",\"src\":")
    _write_json(io, string(var.level))
    print(io, ",\"blob_ref\":")
    _write_json(io, var.blob_ref.hash)
    print(io, "}")
    return nothing
end

function _write_json(io::IO, var::VoidScopeVariable)
    print(io, "{\"src_type\":")
    _write_json(io, var.type_short)
    print(io, ",\"src\":")
    _write_json(io, string(var.level))
    print(io, "}")
    return nothing
end

function _write_json(io::IO, var::HashedScopeVariable)
    print(io, "{\"src_type\":")
    _write_json(io, var.type_short)
    print(io, ",\"src\":")
    _write_json(io, string(var.level))
    print(io, ",\"value_hash\":")
    _write_json(io, var.value_hash)
    print(io, "}")
    return nothing
end

function _write_json(io::IO, scope::ScopeSnapshot)
    print(io, "{\"class_id\":")
    _write_json(io, _SCOPE_CLASS_ID)
    print(io, ",\"class_version\":")
    _write_json(io, _SCOPE_CLASS_VERSION)
    print(io, ",\"labels\":")
    _write_json(io, scope.labels)
    print(io, ",\"variables\":")
    _write_json(io, scope.variables)
    if !isempty(scope.metadata)
        print(io, ",\"metadata\":")
        _write_json(io, scope.metadata)
    end
    print(io, "}")
    return nothing
end

function _write_json(io::IO, tree::CaptureTree)
    _require_scope_class_registration!()
    print(io, "{\"type\":\"commit\",\"metadata\":")
    _write_json(io, tree.metadata)
    # Write ScopeSnapshot entries as "scopes" for tape format compatibility
    scopes = ScopeSnapshot[s for s in tree.snapshots if s isa ScopeSnapshot]
    print(io, ",\"scopes\":")
    _write_json(io, scopes)
    if !isempty(tree.label)
        print(io, ",\"commit_label\":")
        _write_json(io, tree.label)
    end
    print(io, "}")
    return nothing
end

"""
    commit_to_tape!(tape::TapeIO, tree::CaptureTree)

Write a CaptureTree to the tape as a single JSON line.
"""
function commit_to_tape!(tape::TapeIO, tree::CaptureTree)
    append!(tape, tree)
end

"""
    take_stage_commit!(stage::CaptureTree, policy::CapturePolicy; label::String="", metadata::Dict{String,Any}=Dict{String,Any}())

Build a `CaptureTree` (commit node) from the current stage and clear staged snapshots.
Does not write to tape.
"""
function take_stage_commit!(stage::CaptureTree, policy::CapturePolicy;
        label::String = "",
        metadata::Dict{String, Any} = Dict{String, Any}()
    )
    commit = CaptureTree(label, copy(stage.snapshots), copy(stage.children), copy(metadata))
    empty!(stage.snapshots)
    empty!(stage.children)
    empty!(policy.inline_vars)
    return commit
end
