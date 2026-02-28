# ============================================================
# Classes/snap/scope.jl — `snap.scope` class semantics
# ============================================================

const _SCOPE_CLASS_ID = "snap.scope"
const _SCOPE_CLASS_VERSION = 1

"""
    decode_snap_scope_variable_record(name::String, data::AbstractDict) -> ScopeVariable

Decode one variable binding payload from a `snap.scope` record.
"""
function decode_snap_scope_variable_record(name::String, data::AbstractDict)::ScopeVariable
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

function _decode_snap_scope_record_by_class(
        cls::SimuleosClass,
        data::AbstractDict,
    )::ScopeSnapshot
    error("No snap.scope decoder registered for class `$(class_spec_string(cls))`.")
end

function _decode_snap_scope_record_by_class(
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

    variables = Dict{Symbol, ScopeVariable}()
    if haskey(data, "variables")
        for (k, v) in data["variables"]
            name = string(k)
            variables[Symbol(name)] = decode_snap_scope_variable_record(name, v)
        end
    end

    metadata = Dict{Symbol, Any}()
    if haskey(data, "metadata") && data["metadata"] isa AbstractDict
        for (k, v) in data["metadata"]
            metadata[Symbol(k)] = v
        end
    end

    return ScopeSnapshot(labels, variables, metadata)
end

"""
    decode_snap_scope_record(data::AbstractDict) -> ScopeSnapshot

Decode one `snap.scope` payload using class-id dispatch.
"""
function decode_snap_scope_record(data::AbstractDict)::ScopeSnapshot
    cls = _record_class_tag(
        data;
        default_id = _SCOPE_CLASS_ID,
        default_version = _SCOPE_CLASS_VERSION,
        payload_name = "scope",
    )
    return _decode_snap_scope_record_by_class(cls, data)
end

"""
    encode_snap_scope_record!(io::IO, scope::ScopeSnapshot) -> Nothing

Encode one scope payload with `snap.scope` class markers.
"""
function encode_snap_scope_record!(io::IO, scope::ScopeSnapshot)::Nothing
    _write_json_class_header(io, _SCOPE_CLASS_ID, _SCOPE_CLASS_VERSION)
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
