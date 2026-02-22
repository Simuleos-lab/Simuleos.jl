# ============================================================
# json.jl — JSON serialization utilities for tape records
# ============================================================

import JSON3

"""
    _to_json_string(data) -> String

Serialize data to a single-line JSON string.
"""
function _to_json_string(data)
    io = IOBuffer()
    _write_json(io, data)
    return String(take!(io))
end

"""
    _from_json_string(s::String) -> Dict{String, Any}

Parse a JSON string into a Dict with String keys.
"""
function _from_json_string(s::AbstractString)
    raw = JSON3.read(String(s), Dict)
    return _string_keys(raw)
end

"""
    _write_json(io::IO, value)

Write a JSON value to `io`.
Container structure is written manually; primitive/escaping logic is delegated to JSON3.
"""
_write_json(io::IO, value) = JSON3.write(io, value)
_write_json(io::IO, value::Symbol) = JSON3.write(io, string(value))
_write_json(io::IO, value::Dates.DateTime) = JSON3.write(io, string(value))

function _write_json(io::IO, values::AbstractVector)
    print(io, "[")
    for (idx, value) in enumerate(values)
        idx > 1 && print(io, ",")
        _write_json(io, value)
    end
    print(io, "]")
    return nothing
end

function _write_json(io::IO, d::AbstractDict)
    print(io, "{")
    first = true
    for (k, v) in d
        if first
            first = false
        else
            print(io, ",")
        end
        JSON3.write(io, string(k))
        print(io, ":")
        _write_json(io, v)
    end
    print(io, "}")
    return nothing
end
