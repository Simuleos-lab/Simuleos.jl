# ============================================================
# Classes/src/session_state.jl — `src.session_state` class semantics
# ============================================================

const _SRC_SESSION_STATE_CLASS_SPEC = CLASS_SPEC_SRC_SESSION_STATE
const _SRC_SESSION_STATE_CLASS_ID = _class_id(_SRC_SESSION_STATE_CLASS_SPEC)
const _SRC_SESSION_STATE_CLASS_VERSION = _class_version(_SRC_SESSION_STATE_CLASS_SPEC)

function _require_src_session_state_class_registration!()::Nothing
    class_require!(_SRC_SESSION_STATE_CLASS_ID, _SRC_SESSION_STATE_CLASS_VERSION)
    return nothing
end

function _src_session_state_meta(data)::Dict{String, Any}
    data isa AbstractDict || return Dict{String, Any}()
    return _string_keys(data)
end

function _src_session_state_labels(data)::Vector{String}
    data isa AbstractVector || return String[]
    return String[string(label) for label in data]
end

function encode_src_session_state_record(data::AbstractDict)::Dict{String, Any}
    _require_src_session_state_class_registration!()
    return _stamp_class_record(data, _SRC_SESSION_STATE_CLASS_ID, _SRC_SESSION_STATE_CLASS_VERSION)
end

function encode_src_session_state_record(payload::SrcSessionStateV1)::Dict{String, Any}
    return encode_src_session_state_record(Dict{String, Any}(
        "session_id" => payload.session_id,
        "labels" => copy(payload.labels),
        "meta" => copy(payload.meta),
    ))
end

function encode_src_session_state_record(ws::WorkSession)::Dict{String, Any}
    return encode_src_session_state_record(
        SrcSessionStateV1(string(ws.session_id), ws.labels, ws.metadata),
    )
end

function _decode_src_session_state_record_by_class(
        cls::SimuleosClassTag,
        data::AbstractDict,
    )::SrcSessionStateV1
    _no_class_decoder_error("src.session_state", cls, data)
end

function _decode_src_session_state_record_by_class(
        ::SimuleosClassTag{Symbol(_SRC_SESSION_STATE_CLASS_ID), _SRC_SESSION_STATE_CLASS_VERSION},
        data::AbstractDict,
    )::SrcSessionStateV1
    return SrcSessionStateV1(
        string(get(data, "session_id", "")),
        _src_session_state_labels(get(data, "labels", Any[])),
        _src_session_state_meta(get(data, "meta", Dict{String, Any}())),
    )
end

function decode_src_session_state_record(data::AbstractDict)::SrcSessionStateV1
    cls = _record_class_tag(
        data;
        default_id = _SRC_SESSION_STATE_CLASS_ID,
        default_version = _SRC_SESSION_STATE_CLASS_VERSION,
        payload_name = "src.session_state",
    )
    return _decode_src_session_state_record_by_class(cls, data)
end
