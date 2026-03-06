# ============================================================
# Classes/snap/scope.jl — `snap.scope` class semantics
# ============================================================

const _SCOPE_CLASS_SPEC = CLASS_SPEC_SNAP_SCOPE
const _SCOPE_CLASS_ID = _class_id(_SCOPE_CLASS_SPEC)
const _SCOPE_CLASS_VERSION = _class_version(_SCOPE_CLASS_SPEC)

function _require_scope_class_registration!()::Nothing
    class_require!(_SCOPE_CLASS_ID, _SCOPE_CLASS_VERSION)
    return nothing
end

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

function encode_scope_variable_record(var::InlineScopeVariable)::Dict{String, Any}
    return Dict{String, Any}(
        "src_type" => var.type_short,
        "src" => string(var.level),
        "value" => var.value,
    )
end

function encode_scope_variable_record(var::BlobScopeVariable)::Dict{String, Any}
    return Dict{String, Any}(
        "src_type" => var.type_short,
        "src" => string(var.level),
        "blob_ref" => var.blob_ref.hash,
    )
end

function encode_scope_variable_record(var::VoidScopeVariable)::Dict{String, Any}
    return Dict{String, Any}(
        "src_type" => var.type_short,
        "src" => string(var.level),
    )
end

function encode_scope_variable_record(var::HashedScopeVariable)::Dict{String, Any}
    return Dict{String, Any}(
        "src_type" => var.type_short,
        "src" => string(var.level),
        "value_hash" => var.value_hash,
    )
end

function _encode_scope_vars_record(vars::Dict{Symbol, ScopeVariable})::Dict{String, Any}
    out = Dict{String, Any}()
    for name in sort!(collect(keys(vars)); by = string)
        out[_to_string_key(name)] = encode_scope_variable_record(vars[name])
    end
    return out
end

function _decode_snap_scope_record_by_class(
        cls::SimuleosClassTag,
        data::AbstractDict,
    )::SnapScopeV1
    _no_class_decoder_error("snap.scope", cls, data)
end

function _decode_snap_scope_record_by_class(
        ::SimuleosClassTag{Symbol(_SCOPE_CLASS_ID), _SCOPE_CLASS_VERSION},
        data::AbstractDict,
    )::SnapScopeV1
    labels = _decode_namespace_binding_labels(data)
    variables = _decode_namespace_binding_variables(data)
    metadata = _decode_namespace_binding_metadata(data)
    return SnapScopeV1(labels, variables, metadata)
end

"""
    decode_snap_scope_record(data::AbstractDict) -> SnapScopeV1

Decode one `snap.scope` payload using class-id dispatch.
"""
function decode_snap_scope_record(data::AbstractDict)::SnapScopeV1
    cls = _record_class_tag(
        data;
        default_id = _SCOPE_CLASS_ID,
        default_version = _SCOPE_CLASS_VERSION,
        payload_name = "scope",
    )
    return _decode_snap_scope_record_by_class(cls, data)
end

function encode_snap_scope_record(scope::SnapScopeV1)::Dict{String, Any}
    _require_scope_class_registration!()
    out = _stamp_class_record(Dict{String, Any}(
        "labels" => copy(scope.labels),
        "variables" => _encode_scope_vars_record(scope.variables),
    ), _SCOPE_CLASS_ID, _SCOPE_CLASS_VERSION)
    if !isempty(scope.metadata)
        out["metadata"] = Dict{String, Any}(_to_string_key(k) => v for (k, v) in scope.metadata)
    end
    return out
end

"""
    encode_snap_scope_record!(io::IO, scope::SnapScopeV1) -> Nothing

Encode one scope payload with `snap.scope` class markers.
"""
function encode_snap_scope_record!(io::IO, scope::SnapScopeV1)::Nothing
    _write_json(io, encode_snap_scope_record(scope))
    return nothing
end
