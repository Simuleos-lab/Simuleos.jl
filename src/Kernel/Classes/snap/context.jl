# ============================================================
# Classes/snap/context.jl — `snap.context` class semantics
# ============================================================

const _CONTEXT_CLASS_SPEC = CLASS_SPEC_SNAP_CONTEXT
const _CONTEXT_CLASS_ID = _class_id(_CONTEXT_CLASS_SPEC)
const _CONTEXT_CLASS_VERSION = _class_version(_CONTEXT_CLASS_SPEC)

function _require_context_class_registration!()::Nothing
    class_require!(_CONTEXT_CLASS_ID, _CONTEXT_CLASS_VERSION)
    return nothing
end

function _context_labels(data)::Vector{String}
    data isa AbstractVector || return String[]
    return String[string(label) for label in data]
end

function encode_snap_context_record(ctx::SnapContextV1)::Dict{String, Any}
    _require_context_class_registration!()

    out = Dict{String, Any}()
    !isnothing(ctx.settings) && (out["settings"] = encode_src_settings_access_record(ctx.settings))
    !isnothing(ctx.source) && (out["source"] = encode_src_codebase_record(ctx.source))
    !isnothing(ctx.environment) && (out["environment"] = encode_src_runtime_host_record(ctx.environment))
    !isnothing(ctx.execution) && (out["execution"] = encode_src_execution_site_record(ctx.execution))

    out["session_id"] = ctx.session_id
    out["labels"] = copy(ctx.labels)
    return _stamp_class_record(out, _CONTEXT_CLASS_ID, _CONTEXT_CLASS_VERSION)
end

function _decode_context_settings(data::AbstractDict)
    raw = get(data, "settings", nothing)
    raw isa AbstractDict || return nothing
    return decode_src_settings_access_record(raw)
end

function _decode_context_source(data::AbstractDict)
    raw = get(data, "source", nothing)
    raw isa AbstractDict || return nothing
    return decode_src_codebase_record(raw)
end

function _decode_context_environment(data::AbstractDict)
    raw = get(data, "environment", nothing)
    raw isa AbstractDict || return nothing
    return decode_src_runtime_host_record(raw)
end

function _decode_context_execution(data::AbstractDict)
    raw = get(data, "execution", nothing)
    raw isa AbstractDict || return nothing
    return decode_src_execution_site_record(raw)
end

function _decode_snap_context_record_by_class(
        cls::SimuleosClassTag,
        data::AbstractDict,
    )::SnapContextV1
    _no_class_decoder_error("snap.context", cls, data)
end

function _decode_snap_context_record_by_class(
        ::SimuleosClassTag{Symbol(_CONTEXT_CLASS_ID), _CONTEXT_CLASS_VERSION},
        data::AbstractDict,
    )::SnapContextV1
    return SnapContextV1(;
        settings = _decode_context_settings(data),
        source = _decode_context_source(data),
        environment = _decode_context_environment(data),
        execution = _decode_context_execution(data),
        session_id = string(get(data, "session_id", "")),
        labels = _context_labels(get(data, "labels", Any[])),
    )
end

function decode_snap_context_record(data::AbstractDict)::SnapContextV1
    cls = _record_class_tag(
        data;
        default_id = _CONTEXT_CLASS_ID,
        default_version = _CONTEXT_CLASS_VERSION,
        payload_name = "context",
    )
    return _decode_snap_context_record_by_class(cls, data)
end
