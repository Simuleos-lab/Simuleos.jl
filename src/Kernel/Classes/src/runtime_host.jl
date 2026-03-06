# ============================================================
# Classes/src/runtime_host.jl — `src.runtime_host` class semantics
# ============================================================

const _SRC_RUNTIME_HOST_CLASS_SPEC = CLASS_SPEC_SRC_RUNTIME_HOST
const _SRC_RUNTIME_HOST_CLASS_ID = _class_id(_SRC_RUNTIME_HOST_CLASS_SPEC)
const _SRC_RUNTIME_HOST_CLASS_VERSION = _class_version(_SRC_RUNTIME_HOST_CLASS_SPEC)

function _require_src_runtime_host_class_registration!()::Nothing
    class_require!(_SRC_RUNTIME_HOST_CLASS_ID, _SRC_RUNTIME_HOST_CLASS_VERSION)
    return nothing
end

function encode_src_runtime_host_record(data::AbstractDict)::Dict{String, Any}
    _require_src_runtime_host_class_registration!()
    return _stamp_class_record(data, _SRC_RUNTIME_HOST_CLASS_ID, _SRC_RUNTIME_HOST_CLASS_VERSION)
end

function encode_src_runtime_host_record(s::SrcRuntimeHostV1)::Dict{String, Any}
    return encode_src_runtime_host_record(Dict{String, Any}(
        "julia_version" => s.julia_version,
        "hostname" => s.hostname,
        "os" => s.os,
        "word_size" => s.word_size,
        "threads" => s.threads,
        "timestamp" => s.timestamp,
    ))
end

function _decode_src_runtime_host_record_by_class(
        cls::SimuleosClassTag,
        data::AbstractDict,
    )::SrcRuntimeHostV1
    _no_class_decoder_error("src.runtime_host", cls, data)
end

function _decode_src_runtime_host_record_by_class(
        ::SimuleosClassTag{Symbol(_SRC_RUNTIME_HOST_CLASS_ID), _SRC_RUNTIME_HOST_CLASS_VERSION},
        data::AbstractDict,
    )::SrcRuntimeHostV1
    julia_version = string(get(data, "julia_version", ""))
    hostname = string(get(data, "hostname", ""))
    os = string(get(data, "os", ""))
    word_size = Int(get(data, "word_size", 0))
    threads = Int(get(data, "threads", 0))
    timestamp = string(get(data, "timestamp", ""))
    return SrcRuntimeHostV1(julia_version, hostname, os, word_size, threads, timestamp)
end

function decode_src_runtime_host_record(data::AbstractDict)::SrcRuntimeHostV1
    cls = _record_class_tag(
        data;
        default_id = _SRC_RUNTIME_HOST_CLASS_ID,
        default_version = _SRC_RUNTIME_HOST_CLASS_VERSION,
        payload_name = "src.runtime_host",
    )
    return _decode_src_runtime_host_record_by_class(cls, data)
end
