# ============================================================
# Classes/encode_dispatch.jl — Semantic encode dispatch lane
# ============================================================

function _write_json_class_header(
        io::IO,
        class_id::AbstractString,
        class_version::Integer,
    )::Nothing
    print(io, "{\"", CLASS_ID_KEY, "\":")
    _write_json(io, String(class_id))
    print(io, ",\"", CLASS_VERSION_KEY, "\":")
    _write_json(io, Int(class_version))
    return nothing
end

function _stamp_class_record(
        data::AbstractDict,
        class_id::AbstractString,
        class_version::Integer,
    )::Dict{String, Any}
    out = _string_keys(data)
    out[CLASS_ID_KEY] = String(class_id)
    out[CLASS_VERSION_KEY] = Int(class_version)
    return out
end
