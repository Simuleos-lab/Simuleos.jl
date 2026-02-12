# Direct JSON serialization for Simuleos objects (all I0x — pure serialization)
# Avoids intermediate Dict allocation for better commit performance

# Fallback - delegates to JSON3 for primitives
_write_json(io::IO, x) = JSON3.write(io, x)

# Symbol -> String
_write_json(io::IO, s::Symbol) = JSON3.write(io, string(s))

# DateTime -> ISO string
_write_json(io::IO, dt::Dates.DateTime) = JSON3.write(io, string(dt))

# Dict - iterate keys, call _write_json for values
function _write_json(io::IO, d::Dict)
    print(io, "{")
    first = true
    for (k, v) in d
        first || print(io, ",")
        first = false
        _write_json(io, string(k))  # key as string
        print(io, ":")
        _write_json(io, v)
    end
    print(io, "}")
end

# Vector - iterate, call _write_json for elements
function _write_json(io::IO, v::Vector)
    print(io, "[")
    for (i, x) in enumerate(v)
        i > 1 && print(io, ",")
        _write_json(io, x)
    end
    print(io, "]")
end

# Set - same as Vector
function _write_json(io::IO, s::Set)
    print(io, "[")
    first = true
    for x in s
        first || print(io, ",")
        first = false
        _write_json(io, x)
    end
    print(io, "]")
end

# NOTE: ScopeVariable and Scope serialization is now handled by Recorder
# (pipeline-I0x.jl) where blob/lite classification happens at write time.

