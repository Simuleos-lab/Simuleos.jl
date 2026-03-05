# ============================================================
# scopetapes/base.jl — Typed record construction from raw Dict data
# ============================================================

"""
    decode_scope_variable_record(name::String, data::AbstractDict) -> ScopeVariable

Parse a raw JSON dict into the appropriate ScopeVariable subtype.
"""
decode_scope_variable_record(name::String, data::AbstractDict) =
    decode_snap_scope_variable_record(name, data)

"""
    decode_scope_snapshot_record(data::AbstractDict) -> SnapScopeV1

Parse a raw scope dict into a SnapScopeV1.
"""
decode_scope_snapshot_record(data::AbstractDict)::SnapScopeV1 = decode_snap_scope_record(data)

"""
    decode_scope_commit_record(data::AbstractDict) -> RecCaptureCommitV1

Parse a raw commit dict into a RecCaptureCommitV1.
"""
decode_scope_commit_record(data::AbstractDict)::RecCaptureCommitV1 = decode_rec_capture_commit_record(data)
"""
    iterate_commits(tape::TapeIO) -> Vector{RecCaptureCommitV1}

Read commit records from a tape as fully materialized `RecCaptureCommitV1` values.
This keeps the read surface simple (no custom iterator wrappers).
"""
iterate_commits(tape::TapeIO)::Vector{RecCaptureCommitV1} = fetch_scope_commits(tape)
