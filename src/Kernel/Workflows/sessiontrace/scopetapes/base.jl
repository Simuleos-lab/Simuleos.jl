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
    decode_scope_snapshot_record(data::AbstractDict) -> ScopeSnapshot

Parse a raw scope dict into a ScopeSnapshot.
"""
decode_scope_snapshot_record(data::AbstractDict)::ScopeSnapshot = decode_snap_scope_record(data)

"""
    decode_scope_commit_record(data::AbstractDict) -> CaptureTree

Parse a raw commit dict into a CaptureTree.
"""
function decode_scope_commit_record(data::AbstractDict)
    label = string(get(data, "commit_label", ""))
    metadata = Dict{String, Any}()
    if haskey(data, "metadata") && data["metadata"] isa AbstractDict
        metadata = _string_keys(data["metadata"])
    end

    snapshots = PartialSnapshot[]
    if haskey(data, "scopes")
        for scope_data in data["scopes"]
            push!(snapshots, decode_scope_snapshot_record(scope_data))
        end
    end

    return CaptureTree(label, snapshots, CaptureTree[], metadata)
end
"""
    iterate_commits(tape::TapeIO) -> Vector{CaptureTree}

Read commit records from a tape as fully materialized `CaptureTree` values.
This keeps the read surface simple (no custom iterator wrappers).
"""
iterate_commits(tape::TapeIO)::Vector{CaptureTree} = fetch_scope_commits(tape)
