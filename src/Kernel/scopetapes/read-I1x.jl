# ScopeTapes loading functions (all I1x)
# Typed read over low-level TapeIO Dict iteration.

"""
    iterate_tape(tape::TapeIO)

Returns a lazy iterator that yields `ScopeCommit` objects.
"""
function iterate_tape(tape::TapeIO)
    (_raw_to_scope_commit(raw) for raw in tape)
end

import Base.collect
function Base.collect(::Type{Vector{ScopeCommit}}, tape::TapeIO)
    collect(iterate_tape(tape))
end
