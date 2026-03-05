# ============================================================
# scopetapes/write.jl — Writing commits to tape
# ============================================================

"""
    _write_json(io::IO, var::InlineScopeVariable)

Serialize an inline variable record.
"""
function _write_json(io::IO, var::InlineScopeVariable)
    _write_json(io, encode_scope_variable_record(var))
    return nothing
end

function _write_json(io::IO, var::BlobScopeVariable)
    _write_json(io, encode_scope_variable_record(var))
    return nothing
end

function _write_json(io::IO, var::VoidScopeVariable)
    _write_json(io, encode_scope_variable_record(var))
    return nothing
end

function _write_json(io::IO, var::HashedScopeVariable)
    _write_json(io, encode_scope_variable_record(var))
    return nothing
end

function _write_json(io::IO, scope::SnapScopeV1)
    return encode_snap_scope_record!(io, scope)
end

function _write_json(io::IO, scope::SnapSharedV1)
    return encode_snap_shared_record!(io, scope)
end

function _write_json(io::IO, commit::RecCaptureCommitV1)
    _write_json(io, encode_rec_capture_commit_record(commit))
    return nothing
end

"""
    commit_to_tape!(tape::TapeIO, commit::RecCaptureCommitV1)

Write a RecCaptureCommitV1 to the tape as a single JSON line.
"""
function commit_to_tape!(tape::TapeIO, commit::RecCaptureCommitV1)
    append!(tape, commit)
end

"""
    take_stage_commit!(stage::CaptureTree, policy::CapturePolicy; label::String="", metadata::Dict{String,Any}=Dict{String,Any}())

Build a `RecCaptureCommitV1` from the current stage and clear staged snapshots.
Does not write to tape.
"""
function take_stage_commit!(stage::CaptureTree, policy::CapturePolicy;
        label::String = "",
        metadata::Dict{String, Any} = Dict{String, Any}()
    )
    capture = CaptureTree(stage.label, copy(stage.snapshots), copy(stage.children), copy(metadata))
    empty!(stage.snapshots)
    empty!(stage.children)
    empty!(policy.inline_vars)
    return RecCaptureCommitV1(; label=label, capture=capture, metadata=copy(metadata))
end
