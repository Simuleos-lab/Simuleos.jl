# ============================================================
# Classes/snap/context.jl — `snap.context` class semantics
# ============================================================

const _CONTEXT_CLASS_ID = "snap.context"
const _CONTEXT_CLASS_VERSION = 1

function _require_context_class_registration!()::Nothing
    class_require!(_CONTEXT_CLASS_ID, _CONTEXT_CLASS_VERSION)
    return nothing
end

"""
    encode_snap_context_record(data::AbstractDict) -> Dict{String, Any}

Normalize a context payload and stamp `snap.context` class identity.
"""
function encode_snap_context_record(data::AbstractDict)::Dict{String, Any}
    out = _string_keys(data)
    out["class_id"] = _CONTEXT_CLASS_ID
    out["class_version"] = _CONTEXT_CLASS_VERSION
    return out
end

function _decode_snap_context_record_by_class(
        cls::SimuleosClass,
        data::AbstractDict,
    )::Dict{String, Any}
    error("No snap.context decoder registered for class `$(class_spec_string(cls))`.")
end

function _decode_snap_context_record_by_class(
        ::SimuleosClass{Symbol("snap.context"), 1},
        data::AbstractDict,
    )::Dict{String, Any}
    return _string_keys(data)
end

"""
    decode_snap_context_record(data::AbstractDict) -> Dict{String, Any}

Decode one `snap.context` payload using class-id dispatch.
"""
function decode_snap_context_record(data::AbstractDict)::Dict{String, Any}
    cls = _record_class_tag(
        data;
        default_id = _CONTEXT_CLASS_ID,
        default_version = _CONTEXT_CLASS_VERSION,
        payload_name = "context",
    )
    return _decode_snap_context_record_by_class(cls, data)
end
