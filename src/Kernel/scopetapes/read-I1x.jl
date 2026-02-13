# ScopeTapes loading functions (all I1x)
# Provides lazy iteration over tape commits.

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
