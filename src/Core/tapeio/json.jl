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

# ScopeVariable - manual field writing, skip nothing/empty
function _write_json(io::IO, sv::Core.ScopeVariable)
    print(io, "{\"src_type\":")
    _write_json(io, sv.src_type)
    print(io, ",\"src\":")
    _write_json(io, sv.src)
    if !isnothing(sv.value)
        print(io, ",\"value\":")
        _write_json(io, sv.value)
    end
    if !isnothing(sv.blob_ref)
        print(io, ",\"blob_ref\":")
        _write_json(io, sv.blob_ref)
    end
    print(io, "}")
end

# Scope - manual field writing, skip empty collections
function _write_json(io::IO, scope::Core.Scope)
    print(io, "{\"label\":")
    _write_json(io, scope.label)
    print(io, ",\"timestamp\":")
    _write_json(io, scope.timestamp)
    print(io, ",\"variables\":{")
    first = true
    for (name, sv) in scope.variables
        first || print(io, ",")
        first = false
        _write_json(io, name)
        print(io, ":")
        _write_json(io, sv)
    end
    print(io, "}")
    if !isempty(scope.labels)
        print(io, ",\"labels\":")
        _write_json(io, scope.labels)
    end
    if !isempty(scope.data)
        print(io, ",\"data\":")
        _write_json(io, scope.data)
    end
    print(io, "}")
end

