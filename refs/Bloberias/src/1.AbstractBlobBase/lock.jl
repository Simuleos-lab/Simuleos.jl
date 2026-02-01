# -. -- .- ---- - .-. - - .-- . -..... --- -- - .
# TAI:


# -. -- .- ---- - .-. - - .-- . -..... --- -- - .
# To Implement
# A hash for distinguising the object
# It should not change if the object is modified while lk. 
# _lock_obj_identity_hash(obj, h0)::UInt64

# -. -- .- ---- - .-. - - .-- . -..... --- -- - .
# A hash of a collection
function _col_hash(col, h = 0)
    h = hash(h)
    for el in col
        h = hash(el, h)
    end
    return h
end

function _pidfile_path(ab::AbstractBlob, args...; B = bloberia(ab))
    root = bloberiapath(B)
    _hash = _lock_obj_identity_hash(ab, UInt(0)) 
    if !isempty(args)
        _hash = _col_hash(args, _hash) # custom extra args...
    end
    _name = string(typeof(ab), ".", repr(_hash), ".pidfile")
    return joinpath(root, "_locks", _name)
end

function getlockfile(ab::AbstractBlob, args...) 
    B = bloberia(ab)
    # filepath
    _file = _pidfile_path(ab, args...; B)
    # To avoid 
    # AssertionError: Multiple concurrent writes to Dict detected!
    # Im locking the access to the getlockfile
    # TODO: reseach about the best way to do this.
    lk = gettemp!(B, "getlockfile.lk") do 
        ReentrantLock()
    end
    return lock(lk) do
        gettemp!(B, _file) do
            return SimpleLockFile(_file)
        end
    end
end

import Base.lock
function Base.lock(f::Function, ab::AbstractBlob, args...; kwargs...) 

    lk = getlockfile(ab, args...)
    return lock(f, lk; kwargs...)
end

function Base.lock(ab::AbstractBlob, args...; kwargs...) 
    lk = getlockfile(ab, args...)
    return lock(lk; kwargs...)
end

import Base.islocked
function Base.islocked(ab::AbstractBlob, args...) 
    lk = getlockfile(ab, args...)
    isnothing(lk) && return false
    return islocked(lk)
end

import Base.unlock
function Base.unlock(ab::AbstractBlob, args...; force = false) 
    lk = getlockfile(ab, args...)
    isnothing(lk) && return # ignore
    return unlock(lk; force)
end


function __dolock(f::Function, ab::AbstractBlob, lkflag::Bool, args...; kwargs...)
    lkflag ? lock(f, ab, args...; kwargs...) : f()
end