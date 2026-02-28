# ============================================================
# scopetapes/base.jl — Typed record construction from raw Dict data
# ============================================================

const _SCOPE_CLASS_ID = "snap.scope"
const _SCOPE_CLASS_VERSION = 1

function _scope_class_version(raw_version)::Int
    if raw_version isa Integer
        return Int(raw_version)
    end
    if raw_version isa AbstractString
        parsed = try
            parse(Int, strip(String(raw_version)))
        catch
            error("Invalid `class_version` `$(raw_version)` for scope record.")
        end
        return Int(parsed)
    end
    if raw_version isa Real && isinteger(raw_version)
        return Int(round(raw_version))
    end
    error("Invalid `class_version` `$(raw_version)` for scope record.")
end

function _scope_snapshot_class_identity(data::AbstractDict)::Tuple{String, Int}
    class_id = get(data, "class_id", get(data, :class_id, nothing))
    class_version = get(data, "class_version", get(data, :class_version, nothing))

    if isnothing(class_id) && isnothing(class_version)
        return (_SCOPE_CLASS_ID, _SCOPE_CLASS_VERSION)
    end
    isnothing(class_id) && error("Scope record has `class_version` but missing `class_id`.")
    isnothing(class_version) && error("Scope record has `class_id` but missing `class_version`.")

    return (string(class_id), _scope_class_version(class_version))
end

function _scope_snapshot_class_tag(data::AbstractDict)::SimuleosClass
    class_id, class_version = _scope_snapshot_class_identity(data)
    class_require!(class_id, class_version)
    return class_tag(class_id, class_version)
end

function _decode_scope_snapshot_by_class(
        cls::SimuleosClass,
        data::AbstractDict,
    )::ScopeSnapshot
    error("No scope decoder registered for class `$(class_spec_string(cls))`.")
end

"""
    decode_scope_variable_record(name::String, data::AbstractDict) -> ScopeVariable

Parse a raw JSON dict into the appropriate ScopeVariable subtype.
"""
function decode_scope_variable_record(name::String, data::AbstractDict)
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
    decode_scope_snapshot_record(data::AbstractDict) -> ScopeSnapshot

Parse a raw scope dict into a ScopeSnapshot.
"""
function _decode_scope_snapshot_by_class(
        ::SimuleosClass{Symbol("snap.scope"), 1},
        data::AbstractDict,
    )::ScopeSnapshot
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
            variables[Symbol(name)] = decode_scope_variable_record(name, v)
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

function decode_scope_snapshot_record(data::AbstractDict)::ScopeSnapshot
    cls = _scope_snapshot_class_tag(data)
    return _decode_scope_snapshot_by_class(cls, data)
end

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

# Internal compatibility aliases used by existing internals.
_parse_scope_variable(name::String, data::AbstractDict) = decode_scope_variable_record(name, data)
_parse_scope(data::AbstractDict) = decode_scope_snapshot_record(data)
_parse_commit(data::AbstractDict) = decode_scope_commit_record(data)

"""
    iterate_commits(tape::TapeIO) -> Vector{CaptureTree}

Read commit records from a tape as fully materialized `CaptureTree` values.
This keeps the read surface simple (no custom iterator wrappers).
"""
iterate_commits(tape::TapeIO)::Vector{CaptureTree} = fetch_scope_commits(tape)
