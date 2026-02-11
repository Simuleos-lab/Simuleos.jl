# Loading functions for tape and blob data (all I1x — takes handler objects as arguments)
# Provides lazy iteration over tapes and blob loading

# ==================================
# Raw tape iteration
# ==================================

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

function Base.iterate(::_TapeIterator, state)
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

# ==================================
# Typed tape iteration (CommitRecord)
# ==================================

"""
    iterate_tape(handler::TapeHandler)

Returns a lazy iterator that yields `CommitRecord` objects.
"""
function iterate_tape(handler::TapeHandler)
    (_raw_to_commit_record(raw) for raw in iterate_raw_tape(handler))
end

import Base.collect
function Base.collect(::Type{Vector{CommitRecord}}, handler::TapeHandler)
    collect(iterate_tape(handler))
end

# TapeHandler convenience iteration (defaults to typed CommitRecord)

function Base.iterate(handler::TapeHandler)
    iter = iterate_tape(handler)
    result = iterate(iter)
    isnothing(result) && return nothing
    (result[1], (iter, result[2]))
end

function Base.iterate(::TapeHandler, state)
    iter, inner_state = state
    result = iterate(iter, inner_state)
    isnothing(result) && return nothing
    (result[1], (iter, result[2]))
end

Base.IteratorSize(::Type{TapeHandler}) = Base.SizeUnknown()
Base.eltype(::Type{TapeHandler}) = CommitRecord

# ==================================
# Raw blob loading
# ==================================

"""
    load_raw_blob(handler::BlobHandler) -> Any

Deserializes and returns the blob data as a Julia object.
"""
function load_raw_blob(handler::BlobHandler)
    path = _blob_path(handler)
    open(path, "r") do io
        Serialization.deserialize(io)
    end
end

# ==================================
# Typed blob loading (BlobRecord)
# ==================================

"""
    load_blob(handler::BlobHandler) -> BlobRecord

Loads and wraps the blob data.
"""
function load_blob(handler::BlobHandler)::BlobRecord
    BlobRecord(load_raw_blob(handler))
end
