# ============================================================
# Classes/encode_dispatch.jl — Semantic encode dispatch lane
# ============================================================

function _write_json_class_header(
        io::IO,
        class_id::AbstractString,
        class_version::Integer,
    )::Nothing
    print(io, "{\"class_id\":")
    _write_json(io, String(class_id))
    print(io, ",\"class_version\":")
    _write_json(io, Int(class_version))
    return nothing
end
