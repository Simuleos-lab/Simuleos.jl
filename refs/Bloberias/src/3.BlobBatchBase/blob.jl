# ## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# get an existing blob
# TODO/TAI find new name
function blob(bb::BlobBatch, uuid::Integer)
    buuids = getbuuids!(bb)
    uuid ∈ buuids || error("Uuid ", repr(uuid), " not present")
    return bBlob(bb, uuid)
end

# registrer a new blob if it does not exist
function blob!(bb::BlobBatch, uuid::Integer)
    uuid = UInt128(uuid)
    b = bBlob(bb, uuid)
    buuids = getbuuids!(bb)
    uuid ∈ buuids && return b
    isfullbatch(bb) && error("The batch is full, see 'blobcount' and 'vbloblim'")
    push!(buuids, uuid)
    return b
end

# default blob
# blob!(bb::BlobBatch) = blob!(bb, 0)
# random new blob
rblob!(bb::BlobBatch) = blob!(bb, uuid_int())

# ## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
function blobcount(bb::BlobBatch)
    buuids = getbuuids!(bb)
    return length(buuids)
end 

_blobcount_cached(bb::BlobBatch) = 
    get(bb, "meta", "blobs.cached.count") do
        blobcount(bb)
    end