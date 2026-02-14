# ScopeTapes loading functions (all I1x)
# Typed read over low-level TapeIO Dict iteration.

"""
    iterate_tape(tape::TapeIO)

Returns a lazy iterator that yields `CommitRecord` objects.
"""
function iterate_tape(tape::TapeIO)
    (_raw_to_commit_record(raw) for raw in tape)
end

import Base.collect
function Base.collect(::Type{Vector{CommitRecord}}, tape::TapeIO)
    collect(iterate_tape(tape))
end
