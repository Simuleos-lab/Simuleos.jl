# Loading functions for tape and blob data
# Two variants: load_raw_* returns Dict/Vector, load_* returns Wrapper

using JSON3
using Serialization

# Raw tape iteration

"""
    iterate_raw_tape(handler::TapeHandler)

Returns a lazy iterator that yields one Dict per JSONL line.
Each Dict represents a commit record.
"""
function iterate_raw_tape(handler::TapeHandler)
    path = _tape_path(handler)
    isfile(path) || return Dict{String, Any}[]

    _TapeIterator(path)
end

# Custom iterator for lazy line-by-line reading
struct _TapeIterator
    path::String
end

function Base.iterate(ti::_TapeIterator)
    io = open(ti.path, "r")
    state = (io,)
    iterate(ti, state)
end

function Base.iterate(ti::_TapeIterator, state)
    io = state[1]
    while !eof(io)
        line = readline(io)
        isempty(strip(line)) && continue
        parsed = JSON3.read(line, Dict{String, Any})
        return (parsed, state)
    end
    close(io)
    return nothing
end

Base.IteratorSize(::Type{_TapeIterator}) = Base.SizeUnknown()
Base.eltype(::Type{_TapeIterator}) = Dict{String, Any}

# Wrapped tape iteration

"""
    iterate_tape(handler::TapeHandler)

Returns a lazy iterator that yields `CommitWrapper` objects.
"""
function iterate_tape(handler::TapeHandler)
    (CommitWrapper(raw) for raw in iterate_raw_tape(handler))
end

# Raw blob loading

"""
    load_raw_blob(handler::BlobHandler) -> Any

Deserializes and returns the blob data as a Julia object.
"""
function load_raw_blob(handler::BlobHandler)
    path = _blob_path(handler)
    open(path, "r") do io
        deserialize(io)
    end
end

# Wrapped blob loading

"""
    load_blob(handler::BlobHandler) -> BlobWrapper

Loads and wraps the blob data.
"""
function load_blob(handler::BlobHandler)::BlobWrapper
    BlobWrapper(load_raw_blob(handler))
end
