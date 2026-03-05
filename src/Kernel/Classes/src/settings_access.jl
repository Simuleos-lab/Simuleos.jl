# ============================================================
# Classes/src/settings_access.jl — `src.settings_access` class semantics
# ============================================================

const _SRC_SETTINGS_ACCESS_CLASS_SPEC = CLASS_SPEC_SRC_SETTINGS_ACCESS
const _SRC_SETTINGS_ACCESS_CLASS_ID = _class_id(_SRC_SETTINGS_ACCESS_CLASS_SPEC)
const _SRC_SETTINGS_ACCESS_CLASS_VERSION = _class_version(_SRC_SETTINGS_ACCESS_CLASS_SPEC)

function _require_src_settings_access_class_registration!()::Nothing
    class_require!(_SRC_SETTINGS_ACCESS_CLASS_ID, _SRC_SETTINGS_ACCESS_CLASS_VERSION)
    return nothing
end

function encode_src_settings_access_record(data::AbstractDict)::Dict{String, Any}
    _require_src_settings_access_class_registration!()
    return _stamp_class_record(data, _SRC_SETTINGS_ACCESS_CLASS_ID, _SRC_SETTINGS_ACCESS_CLASS_VERSION)
end

function encode_src_settings_access_record(s::SrcSettingsAccessV1)::Dict{String, Any}
    return encode_src_settings_access_record(Dict{String, Any}(
        "accessed" => copy(s.accessed),
        "timestamp" => s.timestamp,
    ))
end

function _decode_src_settings_access_record_by_class(
        cls::SimuleosClassTag,
        data::AbstractDict,
    )::SrcSettingsAccessV1
    error("No src.settings_access decoder registered for class `$(class_spec_string(cls))`.")
end

function _decode_src_settings_access_record_by_class(
        ::SimuleosClassTag{Symbol(_SRC_SETTINGS_ACCESS_CLASS_ID), _SRC_SETTINGS_ACCESS_CLASS_VERSION},
        data::AbstractDict,
    )::SrcSettingsAccessV1
    accessed_raw = get(data, "accessed", Dict{String, Any}())
    accessed = accessed_raw isa AbstractDict ? _string_keys(accessed_raw) : Dict{String, Any}()
    timestamp = string(get(data, "timestamp", ""))
    return SrcSettingsAccessV1(accessed, timestamp)
end

function decode_src_settings_access_record(data::AbstractDict)::SrcSettingsAccessV1
    cls = _record_class_tag(
        data;
        default_id = _SRC_SETTINGS_ACCESS_CLASS_ID,
        default_version = _SRC_SETTINGS_ACCESS_CLASS_VERSION,
        payload_name = "src.settings_access",
    )
    return _decode_src_settings_access_record_by_class(cls, data)
end
