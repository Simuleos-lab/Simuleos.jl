_pidfile(bb::BlobBatch) = joinpath(rootdir(bb), "bb.pidfile")
_getlock(bb::BlobBatch) = get!(() -> SimpleLockFile(_pidfile(bb)), bb["temp"], "_lock")
_setlock!(bb::BlobBatch, lk) = setindex!(bb["temp"], lk, "_lock")

import Base.lock
function Base.lock(f::Function, bb::BlobBatch; kwargs...) 
    lk = _getlock(bb)
    isnothing(lk) && return f() # ignore locking
    lock(f, lk, kwargs...)
end
function Base.lock(bb::BlobBatch; kwargs...) 
    lk = _getlock(bb)
    isnothing(lk) && return # ignore locking 
    lock(lk, kwargs...)
    return bb
end

import Base.islocked
function Base.islocked(bb::BlobBatch) 
    lk = _getlock(bb)
    isnothing(lk) && return false
    return islocked(lk)
end

function Base.unlock(bb::BlobBatch; force = false) 
    lk = _getlock(bb)
    isnothing(lk) && return
    return unlock(lk; force)
end
    