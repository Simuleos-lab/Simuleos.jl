# ============================================================
# scopetapes/read.jl — Typed tape iteration
# ============================================================

"""
    TapeIterator

Wraps a TapeIO to yield typed ScopeCommit objects instead of raw Dicts.
"""
struct TapeIterator
    tape::TapeIO
end

"""
    iterate_tape(tape::TapeIO) -> TapeIterator

Create a typed iterator over a tape file.
Returns ScopeCommit objects.
"""
iterate_tape(tape::TapeIO) = TapeIterator(tape)

function _next_commit_raw(tape::TapeIO, state = nothing)
    result = isnothing(state) ? iterate(tape) : iterate(tape, state)
    while !isnothing(result)
        (raw, new_state) = result
        get(raw, "type", "commit") == "commit" && return (raw, new_state)
        result = iterate(tape, new_state)
    end
    return nothing
end

function Base.iterate(ti::TapeIterator)
    result = _next_commit_raw(ti.tape)
    isnothing(result) && return nothing
    (raw, state) = result
    return (_parse_commit(raw), state)
end

function Base.iterate(ti::TapeIterator, state)
    result = _next_commit_raw(ti.tape, state)
    isnothing(result) && return nothing
    (raw, new_state) = result
    return (_parse_commit(raw), new_state)
end

Base.IteratorSize(::Type{TapeIterator}) = Base.SizeUnknown()
Base.eltype(::Type{TapeIterator}) = ScopeCommit

function Base.collect(ti::TapeIterator)
    commits = ScopeCommit[]
    for commit in ti
        push!(commits, commit)
    end
    return commits
end

function Base.collect(::Type{Vector{ScopeCommit}}, tape::TapeIO)
    return collect(iterate_tape(tape))
end
