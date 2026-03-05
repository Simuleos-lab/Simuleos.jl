# ============================================================
# Classes/src/execution_site.jl — `src.execution_site` class semantics
# ============================================================

const _SRC_EXECUTION_SITE_CLASS_SPEC = CLASS_SPEC_SRC_EXECUTION_SITE
const _SRC_EXECUTION_SITE_CLASS_ID = _class_id(_SRC_EXECUTION_SITE_CLASS_SPEC)
const _SRC_EXECUTION_SITE_CLASS_VERSION = _class_version(_SRC_EXECUTION_SITE_CLASS_SPEC)

function _require_src_execution_site_class_registration!()::Nothing
    class_require!(_SRC_EXECUTION_SITE_CLASS_ID, _SRC_EXECUTION_SITE_CLASS_VERSION)
    return nothing
end

function encode_src_execution_site_record(data::AbstractDict)::Dict{String, Any}
    _require_src_execution_site_class_registration!()
    return _stamp_class_record(data, _SRC_EXECUTION_SITE_CLASS_ID, _SRC_EXECUTION_SITE_CLASS_VERSION)
end

function encode_src_execution_site_record(s::SrcExecutionSiteV1)::Dict{String, Any}
    return encode_src_execution_site_record(Dict{String, Any}(
        "src_file" => s.src_file,
        "src_line" => s.src_line,
        "threadid" => s.threadid,
        "timestamp" => s.timestamp,
    ))
end

function _decode_src_execution_site_record_by_class(
        cls::SimuleosClassTag,
        data::AbstractDict,
    )::SrcExecutionSiteV1
    error("No src.execution_site decoder registered for class `$(class_spec_string(cls))`.")
end

function _decode_src_execution_site_record_by_class(
        ::SimuleosClassTag{Symbol(_SRC_EXECUTION_SITE_CLASS_ID), _SRC_EXECUTION_SITE_CLASS_VERSION},
        data::AbstractDict,
    )::SrcExecutionSiteV1
    src_file = string(get(data, "src_file", ""))
    src_line = Int(get(data, "src_line", 0))
    threadid = Int(get(data, "threadid", 0))
    timestamp = string(get(data, "timestamp", ""))
    return SrcExecutionSiteV1(src_file, src_line, threadid, timestamp)
end

function decode_src_execution_site_record(data::AbstractDict)::SrcExecutionSiteV1
    cls = _record_class_tag(
        data;
        default_id = _SRC_EXECUTION_SITE_CLASS_ID,
        default_version = _SRC_EXECUTION_SITE_CLASS_VERSION,
        payload_name = "src.execution_site",
    )
    return _decode_src_execution_site_record_by_class(cls, data)
end
