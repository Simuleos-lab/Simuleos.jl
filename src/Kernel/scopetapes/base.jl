# ============================================================
# scopetapes/base.jl — Typed record construction from raw Dict data
# ============================================================

"""
    _parse_scope_variable(name::String, data::AbstractDict) -> ScopeVariable

Parse a raw JSON dict into the appropriate ScopeVariable subtype.
"""
function _parse_scope_variable(name::String, data::AbstractDict)
    src_type = get(data, "src_type", "Any")
    level = Symbol(get(data, "src", "local"))

    if haskey(data, "blob_ref")
        return BlobScopeVariable(level, string(src_type), BlobRef(string(data["blob_ref"])))
    elseif haskey(data, "value")
        return InlineScopeVariable(level, string(src_type), data["value"])
    elseif haskey(data, "value_hash")
        return HashedScopeVariable(level, string(src_type), string(data["value_hash"]))
    else
        return VoidScopeVariable(level, string(src_type))
    end
end

"""
    _parse_scope(data::AbstractDict) -> ScopeSnapshot

Parse a raw scope dict into a ScopeSnapshot.
"""
function _parse_scope(data::AbstractDict)
    labels = String[]
    if haskey(data, "labels")
        for l in data["labels"]
            s = string(l)
            s in labels || push!(labels, s)
        end
    end

    # Variables
    variables = Dict{Symbol, ScopeVariable}()
    if haskey(data, "variables")
        for (k, v) in data["variables"]
            name = string(k)
            variables[Symbol(name)] = _parse_scope_variable(name, v)
        end
    end

    # Metadata
    metadata = Dict{Symbol, Any}()
    if haskey(data, "metadata") && data["metadata"] isa AbstractDict
        for (k, v) in data["metadata"]
            metadata[Symbol(k)] = v
        end
    end

    return ScopeSnapshot(labels, variables, metadata)
end

"""
    _parse_commit(data::AbstractDict) -> CaptureTree

Parse a raw commit dict into a CaptureTree.
"""
function _parse_commit(data::AbstractDict)
    label = string(get(data, "commit_label", ""))
    metadata = Dict{String, Any}()
    if haskey(data, "metadata") && data["metadata"] isa AbstractDict
        metadata = _string_keys(data["metadata"])
    end

    snapshots = PartialSnapshot[]
    if haskey(data, "scopes")
        for scope_data in data["scopes"]
            push!(snapshots, _parse_scope(scope_data))
        end
    end

    return CaptureTree(label, snapshots, CaptureTree[], metadata)
end

"""
    iterate_commits(tape::TapeIO) -> Vector{CaptureTree}

Read commit records from a tape as fully materialized `CaptureTree` values.
This keeps the read surface simple (no custom iterator wrappers).
"""
function iterate_commits(tape::TapeIO)::Vector{CaptureTree}
    raw_commits = each_tape_records_filtered(
        tape;
        line_filter = (line, ctx) -> occursin("\"type\":\"commit\"", line),
        json_filter = (raw, ctx) -> get(raw, "type", "") == "commit",
    )
    commits = CaptureTree[]
    for raw in raw_commits
        push!(commits, _parse_commit(raw))
    end
    return commits
end
