function _st_get_blob(ST::ScopeTape, st_hash::String)
    # try to find on cache
    if haskey(ST.recording_blob_cache, st_hash) 
        return ST.recording_blob_cache[st_hash]
    end
    # try dick blobs
    blobfile = st_blobfile(ST, st_hash)
    return st_deserialize(blobfile, nothing)
end