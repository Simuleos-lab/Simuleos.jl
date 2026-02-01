## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Constructor

BlobBatch(B::Bloberia, id) = BlobBatch(B, id,
    _batchpath(B.root, id),  # root
    FRAMES_DEPOT_TYPE(),
    DICT_DEPOT_TYPE()
)


## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# rename_bb
rename_bb(bb::BlobBatch, id::String) = BlobBatch(
    bb.B, id,
    _batchpath(bb.B.root, id),  # root
    bb.frames,
    DICT_DEPOT_TYPE()
)

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# shallow copy 
Base.copy(bb::BlobBatch) = BlobBatch(bb.B, bb.id)

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# file sys

# build path
_batchpath(B_root::String, id::String) = joinpath(B_root, id)

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Bloberia interface

bloberia(bb::BlobBatch) = bb.B
blobbatch(bb::BlobBatch) = bb
batchpath(bb::BlobBatch) = bb.root

batchpath(ab::AbstractBlob) = batchpath(blobbatch(ab))

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# custom depots

_getmeta_I!(bb::BlobBatch) = getframe!(bb, "meta")
_gettemp_I!(bb::BlobBatch) = bb.temp

# return the registry of bBlob uuids
function getbuuids!(bb::BlobBatch)
    return get!(bb, "buuids", "reg") do
        Set{UInt128}()
    end
end


## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# An identity hash for the object
function _lock_obj_identity_hash(bb::BlobBatch, h0 = UInt64(0))::UInt64
    h = hash(h0)
    h = hash(:BlobBatch, h)
    h = hash(batchpath(bb), h)
    return h
end

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Set the batch bframes limit
function bloblim(bb::BlobBatch)
    bb_lim = getmeta(bb, "config.blobs.lim", -1)::Int
    bb_lim > 0 && return bb_lim
    
    B_lim = getmeta(bb.B, "config.batches.blobs.lim", -1)::Int
    B_lim > 0 && return B_lim

    return typemax(Int)
end

function bloblim!(bb::BlobBatch, lim::Int)
    setmeta!(bb, lim, "config.blobs.lim")
end

function isfullbatch(bb::BlobBatch)
    return blobcount(bb) >= bloblim(bb)
end

function isoverflowed(bb::BlobBatch)
    return blobcount(bb) > bloblim(bb)
end

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
