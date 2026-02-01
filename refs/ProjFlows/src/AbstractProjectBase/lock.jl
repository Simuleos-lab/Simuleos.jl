_pidfile(p::AbstractProject) = joinpath(dotprojflow_dir(p), "p.pidfile")
_getlockfile(p::AbstractProject) = get!(() -> SimpleLockFile(_pidfile(p)), p.extras, "_lock")
_setlockfile!(p::AbstractProject, lk) = setindex!(p.extras, lk, "_lock")

import Base.lock
function Base.lock(f::Function, p::AbstractProject; kwargs...) 
    lk = _getlockfile(p)
    isnothing(lk) && return f() # ignore locking
    lock(f, lk, kwargs...)
end
function Base.lock(p::AbstractProject; kwargs...) 
    lk = _getlockfile(p)
    isnothing(lk) && return # ignore locking 
    lock(lk, kwargs...)
    return p
end

import Base.islocked
function Base.islocked(p::AbstractProject) 
    lk = _getlockfile(p)
    isnothing(lk) && return false
    return islocked(lk)
end

function Base.unlock(p::AbstractProject; force = false) 
    lk = _getlockfile(p)
    isnothing(lk) && return
    return unlock(lk; force)
end
    
