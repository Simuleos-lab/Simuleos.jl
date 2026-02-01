## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# The blobbatch iterate accross the blobs

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# This is running sllow, see vblobcount(B)
function eachblob_ch(bb::BlobBatch; ch_size = 0)
    return Channel{bBlob}(ch_size) do _ch
        buuids = getbuuids!(bb)
        for uuid in buuids
            # I do not need to check if blob exist
            b = bBlob(bb, uuid) 
            put!(_ch, b)
        end
    end
end

function eachblob(bb::BlobBatch)
    buuids = getbuuids!(bb)
    return (bBlob(bb, uuid) for uuid in buuids)
end

# --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Iterator
function _bb_iterate_next(iter, iter_next)
    isnothing(iter_next) && return nothing
    item, iter_state = iter_next
    bb_state = (iter, iter_state)
    return (item, bb_state)
end

import Base.iterate
function Base.iterate(bb::BlobBatch)
    iter = eachblob(bb)
    iter_next = iterate(iter)
    return _bb_iterate_next(iter, iter_next)
end

function Base.iterate(::BlobBatch, bb_state) 
    isnothing(bb_state) && return nothing
    iter, iter_state = bb_state
    iter_next = iterate(iter, iter_state)
    return _bb_iterate_next(iter, iter_next)
end

import Base.length
Base.length(bb::BlobBatch) = blobcount(bb)