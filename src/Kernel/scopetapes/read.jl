# ============================================================
# scopetapes/read.jl — Typed tape iteration
# ============================================================

"""
    CommitIterator

Wraps a TapeIO to yield typed ScopeCommit objects instead of raw Dicts.
"""
struct CommitIterator
    raw_iter::FilteredTapeRecordIterator
end

const _COMMIT_ITER_TYPE_KEY_NEEDLE = "\"type\":"
const _COMMIT_ITER_COMMIT_TYPE_NEEDLE = "\"type\":\"commit\""

@inline function _commit_iter_line_filter(line::AbstractString, _ctx)
    # Common fast path first. Keep lines without a `type` field as candidates to
    # preserve the legacy/default commit semantics enforced by the JSON filter.
    occursin(_COMMIT_ITER_COMMIT_TYPE_NEEDLE, line) && return true
    occursin(_COMMIT_ITER_TYPE_KEY_NEEDLE, line) && return false
    return true
end

@inline _commit_iter_json_filter(raw::AbstractDict, _ctx) = get(raw, "type", "commit") == "commit"

"""
    iterate_commits(tape::TapeIO) -> CommitIterator

Create a typed iterator over a tape file.
Returns ScopeCommit objects.
"""
function iterate_commits(tape::TapeIO)
    return CommitIterator(each_tape_records_filtered(
        tape;
        line_filter = _commit_iter_line_filter,
        json_filter = _commit_iter_json_filter,
    ))
end

function Base.iterate(ci::CommitIterator)
    result = iterate(ci.raw_iter)
    isnothing(result) && return nothing
    (raw, state) = result
    return (_parse_commit(raw), state)
end

function Base.iterate(ci::CommitIterator, state)
    result = iterate(ci.raw_iter, state)
    isnothing(result) && return nothing
    (raw, new_state) = result
    return (_parse_commit(raw), new_state)
end

Base.IteratorSize(::Type{CommitIterator}) = Base.SizeUnknown()
Base.eltype(::Type{CommitIterator}) = ScopeCommit

function Base.collect(ci::CommitIterator)
    commits = ScopeCommit[]
    for commit in ci
        push!(commits, commit)
    end
    return commits
end

function Base.collect(::Type{Vector{ScopeCommit}}, tape::TapeIO)
    return collect(iterate_commits(tape))
end
