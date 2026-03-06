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
        JSON3.write(io, _to_string_key(k))
        print(io, ":")
        _write_json(io, v)
    end
    print(io, "}")
    return nothing
end

"""
    _write_json_sorted(io::IO, d::AbstractDict)

Write a Dict as JSON with keys sorted lexicographically for deterministic output.
Nested dicts are also sorted recursively.
"""
function _write_json_sorted(io::IO, d::AbstractDict)
    print(io, "{")
    sorted_keys = sort!(collect(keys(d)); by = _to_string_key)
    first = true
    for k in sorted_keys
        if first
            first = false
        else
            print(io, ",")
        end
        JSON3.write(io, _to_string_key(k))
        print(io, ":")
        v = d[k]
        if v isa AbstractDict
            _write_json_sorted(io, v)
        elseif v isa AbstractVector
            _write_json_sorted_vector(io, v)
        else
            _write_json(io, v)
        end
    end
    print(io, "}")
    return nothing
end

function _write_json_sorted_vector(io::IO, v::AbstractVector)
    print(io, "[")
    for (idx, item) in enumerate(v)
        idx > 1 && print(io, ",")
        if item isa AbstractDict
            _write_json_sorted(io, item)
        elseif item isa AbstractVector
            _write_json_sorted_vector(io, item)
        else
            _write_json(io, item)
        end
    end
    print(io, "]")
    return nothing
end

"""
    _to_json_string_sorted(data) -> String

Serialize data to a single-line JSON string with sorted keys for deterministic hashing.
"""
function _to_json_string_sorted(data)::String
    io = IOBuffer()
    if data isa AbstractDict
        _write_json_sorted(io, data)
    elseif data isa AbstractVector
        _write_json_sorted_vector(io, data)
    else
        _write_json(io, data)
    end
    return String(take!(io))
end
