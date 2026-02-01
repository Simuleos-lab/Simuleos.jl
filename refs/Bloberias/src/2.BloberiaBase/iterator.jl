## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
function _is_bbpath_heuristic(path)
    isdir(path) || return false
    for name in readdir(path; join = false)
        endswith(name, ".frame.jls") && return true
    end
    return false
end

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# iterate batch dirs
function _eachbatchdir_gen(B::Bloberia, sortfun::Function)
    root0 = bloberiapath(B)
    paths = sortfun(readdir(root0; join = true))
    paths = isdir(root0) ? paths : String[]
    return (path for path in paths if _is_bbpath_heuristic(path))
end


function _eachbatchdir_ch(B::Bloberia, ch_size, sortfun)
    return Channel{String}(ch_size) do _ch
        for path in _eachbatchdir_gen(B, sortfun)
            put!(_ch, path)
        end
    end
end

# 'preload': frames to preload
_startswith(bbid, bbid_prefix) = startswith(bbid, bbid_prefix) 
_startswith(bbid, bbid_prefix::Nothing) = true

_bb_from_path(B::Bloberia, path) = BlobBatch(B, basename(path))
function _bb_from_path(B::Bloberia, path, bbid_prefix, preload)
    bbid = basename(path)
    # filter
    _startswith(bbid, bbid_prefix) || return nothing
    bb = BlobBatch(B, bbid)
    for frameid in preload
        _try_load_frame!(bb, frameid)
    end
    return bb
end

# returns a channel which iterates for all batches 
# you can filter them
# you can control the order
# TODO/ make threaded version to return batches in order
# - You can do that by spawing load tasks and fetch them  in order
function _eachbatch_th_ch1(B::Bloberia, bbid_prefix = nothing; 
        sortfun = identity, 
        ch_size::Int = 1,
        n_tasks::Int = nthreads(),
        preload = []
    )
    @assert ch_size > 0
    @assert n_tasks > 0
    
    tasks_ch = Channel{Task}(n_tasks) do _ch
        dir_ch = _eachbatchdir_ch(B, ch_size, sortfun)
        for path in dir_ch
            tsk = @spawn _bb_from_path(B, path, bbid_prefix, preload)
            put!(_ch, tsk)
        end
    end

    return Channel{BlobBatch}(ch_size) do _ch
        # here I need the ch for locking
        for tks in tasks_ch
            bb = fetch(tks)
            isnothing(bb) && continue
            put!(_ch, bb)
        end
    end # Channel
end

# MARK:_eachbatch_th_ch2
function _eachbatch_th_ch2(B::Bloberia, bbid_prefix = nothing; 
        sortfun = identity, 
        ch_size::Int = 1,
        n_tasks::Int = nthreads(),
        preload = []
    )
    @assert ch_size > 0
    @assert n_tasks > 0
    
    return Channel{BlobBatch}(ch_size) do _ch
        # here I need the ch for locking
        dir_ch = _eachbatchdir_ch(B, ch_size, sortfun)
        @sync for _ in 1:n_tasks
            @spawn for path in dir_ch
                bb = _bb_from_path(B, path, bbid_prefix, preload)
                isnothing(bb) && continue
                put!(_ch, bb)
            end
        end 
    end # Channel
end

function _eachbatch_ser_ch(B::Bloberia, bbid_prefix = nothing; 
        sortfun = identity, 
        ch_size::Int = 1,
        preload = []
    )
    @assert ch_size > 0
    
    # channel
    return Channel{BlobBatch}(ch_size) do _ch
        file_ch = _eachbatchdir_gen(B, sortfun)
        for path in file_ch
            bb = _bb_from_path(B, path, bbid_prefix, preload)
            isnothing(bb) && continue
            put!(_ch, bb)
        end
    end
end

function eachbatch(B::Bloberia, bbid_prefix = nothing; 
        sortfun = identity, 
        ch_size::Int = getmeta(B, "eachbatch.ch_size", nthreads()),
        n_tasks::Int = getmeta(B, "eachbatch.n_tasks", nthreads()),
        preload = getmeta(B, "eachbatch.preload", String[])
    )
    if n_tasks > 1
        return _eachbatch_th_ch1(B, bbid_prefix; sortfun, ch_size, n_tasks, preload)
    else
        return _eachbatch_ser_ch(B, bbid_prefix; sortfun, ch_size, preload)
    end
end

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# foreach_batch

# version without using channels
function _foreach_batch_chless(f::Function, B::Bloberia)
    bb_root = bloberiapath(B)
    isdir(bb_root) || return nothing
    for path in readdir(bb_root; join = true)
        _is_bbpath_heuristic(path) || continue
        ret = f(path)
        ret === :break && break
    end
    return nothing
end

function _foreach_batch_ser(f::Function, B::Bloberia, bbid_prefix = nothing; 
        sortfun = identity, 
        ch_size::Int = 1, 
        preload = [], 
        lk = false
    )
    bbs = _eachbatch_ser_ch(B, bbid_prefix; sortfun, ch_size, preload)
    for bb in bbs
        __dolock(bb, lk) do
            ret = f(bb)
            ret === :break && close(bbs)
        end
    end
    return nothing
end

# .-- .- -.-.-.--. ...---. . . . -- .--. -. -. -.
function _foreach_batch_th(f::Function, B::Bloberia, bbid_prefix = nothing; 
        sortfun = identity, 
        ch_size::Int = 1, 
        n_tasks::Int = nthreads(), 
        preload = [], 
        lk = false
    )

    # channel
    bbs = _eachbatch_ser_ch(B, bbid_prefix; sortfun, ch_size, preload)

    # spawn
    @sync for _ in 1:n_tasks
        @spawn for bb in bbs
            __dolock(bb, lk) do
                ret = f(bb)
                ret === :break && close(bbs)
            end
        end # for bb
    end
    return nothing
end

# the execution of `f()` is in concurrent if n_tasks > 1
function foreach_batch(f::Function, B::Bloberia, bbid_prefix = nothing; 
        sortfun = identity, 
        ch_size::Int = getmeta(B, "foreach_batch.ch_size", nthreads()), 
        n_tasks::Int = getmeta(B, "foreach_batch.n_tasks", nthreads()), 
        preload = getmeta(B, "foreach_batch.preload", []),
        lk = getmeta(B, "foreach_batch.preload", false),
    )
    if n_tasks > 1
        _foreach_batch_th(f, B, bbid_prefix; sortfun, ch_size, n_tasks, preload, lk)
    else
        _foreach_batch_ser(f, B, bbid_prefix; sortfun, ch_size, preload, lk)
    end
    return nothing
end

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Iterator
function _B_iterate_next(iter, iter_next)
    isnothing(iter_next) && return nothing
    item, ch_state = iter_next
    B_state = (iter, ch_state)
    return (item, B_state)
end

import Base.iterate
function Base.iterate(B::Bloberia)
    iter = _eachbatch_ser_ch(B, nothing)
    iter_next = iterate(iter)
    return _B_iterate_next(iter, iter_next)
end

function Base.iterate(::Bloberia, B_state) 
    isnothing(B_state) && return nothing
    iter, iter_state = B_state
    iter_next = iterate(iter, iter_state)
    return _B_iterate_next(iter, iter_next)
end

