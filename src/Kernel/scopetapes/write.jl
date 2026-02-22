# ============================================================
# scopetapes/write.jl — Writing commits to tape
# ============================================================

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

function _write_json(io::IO, scope::SimuleosScope)
    print(io, "{\"labels\":")
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

function _write_json(io::IO, commit::ScopeCommit)
    print(io, "{\"type\":\"commit\",\"metadata\":")
    _write_json(io, commit.metadata)
    print(io, ",\"scopes\":")
    _write_json(io, commit.scopes)
    if !isempty(commit.commit_label)
        print(io, ",\"commit_label\":")
        _write_json(io, commit.commit_label)
    end
    print(io, "}")
    return nothing
end

"""
    commit_to_tape!(tape::TapeIO, commit::ScopeCommit)

Write a ScopeCommit to the tape as a single JSON line.
"""
function commit_to_tape!(tape::TapeIO, commit::ScopeCommit)
    append!(tape, commit)
end

"""
    commit_stage!(tape::TapeIO, stage::ScopeStage; label::String="", metadata::Dict{String,Any}=Dict{String,Any}())

Flush the current stage to the tape as a single commit.
Clears the stage captures after writing.
Returns the ScopeCommit that was written.
"""
function commit_stage!(tape::TapeIO, stage::ScopeStage;
        label::String = "",
        metadata::Dict{String, Any} = Dict{String, Any}()
    )
    commit = ScopeCommit(label, metadata, copy(stage.captures))
    commit_to_tape!(tape, commit)
    empty!(stage.captures)
    empty!(stage.inline_vars)
    return commit
end
