# TapeIO subsystem (all I0x)
# Path-based JSONL I/O with Dict records only.

function _normalize_tape_value(value)
    if value isa AbstractDict
        out = Dict{String, Any}()
        for (k, v) in value
            out[string(k)] = _normalize_tape_value(v)
        end
        return out
    elseif value isa AbstractVector
        return Any[_normalize_tape_value(v) for v in value]
    elseif value isa Set
        return Any[_normalize_tape_value(v) for v in value]
    else
        return value
    end
end

function append!(tape::TapeIO, rec::AbstractDict)
    normalized = _normalize_tape_value(rec)
    mkpath(dirname(tape.path))
    open(tape.path, "a") do io
        _write_json(io, normalized)
        println(io)
    end
    return nothing
end

function Base.iterate(tape::TapeIO)
    isfile(tape.path) || return nothing
    io = open(tape.path, "r")
    state = (io, 0)
    iterate(tape, state)
end

function Base.iterate(tape::TapeIO, state)
    io, line_no = state
    while !eof(io)
        line = readline(io)
        line_no += 1
        isempty(strip(line)) && continue
        parsed = try
            JSON3.read(line, Dict{String, Any})
        catch err
            close(io)
            error("Invalid JSON in tape $(tape.path) at line $(line_no): $(sprint(showerror, err))")
        end
        return (parsed, (io, line_no))
    end
    close(io)
    return nothing
end

Base.IteratorSize(::Type{TapeIO}) = Base.SizeUnknown()
Base.eltype(::Type{TapeIO}) = Dict{String, Any}
