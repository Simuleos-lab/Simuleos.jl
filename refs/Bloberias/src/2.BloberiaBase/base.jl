## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Constructor
Bloberia(root) = Bloberia(root, FRAMES_DEPOT_TYPE(), DICT_DEPOT_TYPE())

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# shallow copy 
import Base.copy
Base.copy(B::Bloberia) = Bloberia(B.root) 

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Bloberia interface

bloberia(B::Bloberia) = B
bloberiapath(B::Bloberia) = B.root
bloberiapath(ab::AbstractBlob) = bloberiapath(bloberia(ab))

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# custom depots

_getmeta_I!(B::Bloberia) = getframe!(B, "meta")
_gettemp_I!(B::Bloberia) = B.temp

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# lock interface
function _lock_obj_identity_hash(B::Bloberia, h0 = UInt64(0))::UInt64
    h = hash(h0)
    h = hash(:Bloberia, h)
    h = hash(bloberiapath(B), h)
    return h
end

function unlock_batches(B::Bloberia; force = false)
    for bb in B
        unlock(bb; force)
    end
end

function lockcount(B)
    root = bloberiapath(B)
    lkdir = joinpath(root, "_locks")
    isdir(lkdir) || return 0
    c = 0
    for name in readdir(lkdir)
        endswith(name, ".pidfile") || continue
        c += 1
    end
    return c
end

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
function _blobcount_tout(B::Bloberia, bbid_prefix, tout; 
        blobcountfun = _blobcount_cached
    )
    _lk = ReentrantLock()
    _tot_count = 0
    _t0 = time()
    _isout = false

    ch_size = nthreads() * 2
    n_tasks = nthreads()
    foreach_batch(
        B, bbid_prefix; ch_size, n_tasks
    ) do _bb
        _isout = tout > 0 && time() - _t0 > tout
        _isout && return :break
        _count = blobcountfun(_bb)
        lock(_lk) do
            _tot_count += _count
        end
    end
    return (_isout, _tot_count)
end

function blobcount(B::Bloberia, bbid_prefix = nothing)
    _, count = _blobcount_tout(B::Bloberia, bbid_prefix, Inf)
    return count
end
