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

"""
    iterate_commits(tape::TapeIO) -> CommitIterator

Create a typed iterator over a tape file.
Returns ScopeCommit objects.
"""
function iterate_commits(tape::TapeIO)
    line_filter = function (line::AbstractString, ctx)
        # Fast skip for common non-commit record; keep lines without a top-level-like
        # type marker as candidates so older/malformed commit rows still reach JSON check.
        occursin("\"type\":\"tape_metadata\"", line) && return false
        occursin("\"type\":", line) || return true
        return occursin("\"type\":\"commit\"", line)
    end
    json_filter = (raw, ctx) -> get(raw, "type", "commit") == "commit"
    return CommitIterator(each_tape_records_filtered(tape; line_filter=line_filter, json_filter=json_filter))
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
