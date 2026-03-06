# ============================================================
# Classes/snap/shared.jl — `snap.shared` class semantics
# ============================================================

const _SHARED_CLASS_SPEC = CLASS_SPEC_SNAP_SHARED
const _SHARED_CLASS_ID = _class_id(_SHARED_CLASS_SPEC)
const _SHARED_CLASS_VERSION = _class_version(_SHARED_CLASS_SPEC)

function _require_shared_class_registration!()::Nothing
    class_require!(_SHARED_CLASS_ID, _SHARED_CLASS_VERSION)
    return nothing
end

function _decode_shared_key(data::AbstractDict)::String
    haskey(data, "shared_key") || error("`snap.shared` record is missing required `shared_key` field.")
    key = strip(string(data["shared_key"]))
    isempty(key) && error("`snap.shared` record `shared_key` must be non-empty.")
    return key
end

function _decode_snap_shared_record_by_class(
        cls::SimuleosClassTag,
        data::AbstractDict,
    )::SnapSharedV1
    _no_class_decoder_error("snap.shared", cls, data)
end

function _decode_snap_shared_record_by_class(
        ::SimuleosClassTag{Symbol(_SHARED_CLASS_ID), _SHARED_CLASS_VERSION},
        data::AbstractDict,
    )::SnapSharedV1
    labels = _decode_namespace_binding_labels(data)
    variables = _decode_namespace_binding_variables(data)
    metadata = _decode_namespace_binding_metadata(data)
    shared_key = _decode_shared_key(data)
    return SnapSharedV1(labels, variables, metadata, shared_key)
end

"""
    decode_snap_shared_record(data::AbstractDict) -> SnapSharedV1

Decode one `snap.shared` payload using class-id dispatch.
"""
function decode_snap_shared_record(data::AbstractDict)::SnapSharedV1
    cls = _record_class_tag(
        data;
        default_id = _SHARED_CLASS_ID,
        default_version = _SHARED_CLASS_VERSION,
        payload_name = "shared",
    )
    return _decode_snap_shared_record_by_class(cls, data)
end

function encode_snap_shared_record(scope::SnapSharedV1)::Dict{String, Any}
    _require_shared_class_registration!()
    key = strip(scope.shared_key)
    isempty(key) && error("`SnapSharedV1.shared_key` must be non-empty for `snap.shared` encoding.")

    out = _stamp_class_record(Dict{String, Any}(
        "shared_key" => key,
        "labels" => copy(scope.labels),
        "variables" => _encode_scope_vars_record(scope.variables),
    ), _SHARED_CLASS_ID, _SHARED_CLASS_VERSION)
    if !isempty(scope.metadata)
        out["metadata"] = Dict{String, Any}(_to_string_key(k) => v for (k, v) in scope.metadata)
    end
    return out
end

"""
    encode_snap_shared_record!(io::IO, scope::SnapSharedV1) -> Nothing

Encode one shared scope payload with `snap.shared` class markers.
"""
function encode_snap_shared_record!(io::IO, scope::SnapSharedV1)::Nothing
    _write_json(io, encode_snap_shared_record(scope))
    return nothing
end
