# ============================================================
# Classes/decode_dispatch.jl — Semantic decode dispatch lane
# ============================================================

function _no_class_decoder_error(
        domain::AbstractString,
        cls::SimuleosClassTag,
        data::AbstractDict,
    )::Union{}
    data_keys = try
        join(sort!(collect(String, keys(data))), ", ")
    catch
        "<unavailable>"
    end
    error(
        "No `$(domain)` decoder registered for class `$(class_spec_string(cls))`. ",
        "Data keys: [$(data_keys)]",
    )
end

function _class_version_value(raw_version, payload_name::AbstractString)::Int
    if raw_version isa Integer
        return Int(raw_version)
    end
    if raw_version isa AbstractString
        parsed = try
            parse(Int, strip(String(raw_version)))
        catch
            error("Invalid `class_version` `$(raw_version)` for `$(payload_name)` record.")
        end
        return Int(parsed)
    end
    if raw_version isa Real && isinteger(raw_version)
        return Int(round(raw_version))
    end
    error("Invalid `class_version` `$(raw_version)` for `$(payload_name)` record.")
end

function _record_class_identity(
        data::AbstractDict;
        default_id::AbstractString,
        default_version::Integer,
        payload_name::AbstractString = "record",
    )::Tuple{String, Int}
    class_id = _record_class_id_value(data; default = nothing)
    class_version = _record_class_version_raw(data; default = nothing)

    if isnothing(class_id) && isnothing(class_version)
        return (String(default_id), Int(default_version))
    end
    isnothing(class_id) && error("`$(payload_name)` record has `class_version` but missing `class_id`.")
    isnothing(class_version) && error("`$(payload_name)` record has `class_id` but missing `class_version`.")

    return (string(class_id), _class_version_value(class_version, payload_name))
end

function _record_class_tag(
        data::AbstractDict;
        default_id::AbstractString,
        default_version::Integer,
        payload_name::AbstractString = "record",
    )::SimuleosClassTag
    class_id, class_version = _record_class_identity(
        data;
        default_id = default_id,
        default_version = default_version,
        payload_name = payload_name,
    )
    class_require!(class_id, class_version)
    return class_tag(class_id, class_version)
end
