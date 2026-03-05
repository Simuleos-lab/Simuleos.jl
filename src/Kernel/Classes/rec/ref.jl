# ============================================================
# Classes/rec/ref.jl — `rec.ref` class semantics
# ============================================================

const _REC_REF_CLASS_SPEC = CLASS_SPEC_REC_REF
const _REC_REF_CLASS_ID = _class_id(_REC_REF_CLASS_SPEC)
const _REC_REF_CLASS_VERSION = _class_version(_REC_REF_CLASS_SPEC)

function _require_rec_ref_class_registration!()::Nothing
    class_require!(_REC_REF_CLASS_ID, _REC_REF_CLASS_VERSION)
    return nothing
end

function encode_rec_ref_record(ref::RecRefV1)::Dict{String, Any}
    _require_rec_ref_class_registration!()
    return _stamp_class_record(Dict{String, Any}(
        "record_hash" => ref.record_hash,
        "record_short" => ref.record_short,
        "writer" => ref.writer,
        "timetag" => ref.timetag,
        "payload" => ref.payload,
    ), _REC_REF_CLASS_ID, _REC_REF_CLASS_VERSION)
end

function _decode_rec_ref_record_by_class(
        cls::SimuleosClassTag,
        data::AbstractDict,
    )::RecRefV1
    error("No rec.ref decoder registered for class `$(class_spec_string(cls))`.")
end

function _decode_rec_ref_record_by_class(
        ::SimuleosClassTag{Symbol(_REC_REF_CLASS_ID), _REC_REF_CLASS_VERSION},
        data::AbstractDict,
    )::RecRefV1
    return RecRefV1(;
        record_hash = string(get(data, "record_hash", "")),
        record_short = string(get(data, "record_short", "")),
        writer = string(get(data, "writer", "")),
        timetag = string(get(data, "timetag", "")),
        payload = get(data, "payload", nothing),
    )
end

function decode_rec_ref_record(data::AbstractDict)::RecRefV1
    cls = _record_class_tag(
        data;
        default_id = _REC_REF_CLASS_ID,
        default_version = _REC_REF_CLASS_VERSION,
        payload_name = "rec.ref",
    )
    return _decode_rec_ref_record_by_class(cls, data)
end
